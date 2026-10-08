#include "protocol.hpp"
#include "svg-renderer.hpp"

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <Jianzi.hpp>
#include <nlohmann/json.hpp>

extern "C" void __wasm_call_ctors();

// Emscripten uses this to refresh JS typed-array views after memory.grow.
// Typst has no JS views; the notification has no work to perform here.
extern "C" void emscripten_notify_memory_growth(int) {}

namespace {
// Volatile forces these to live in linear memory, which plugin.transition
// snapshots. Do not store initialized state in a WebAssembly global.
qin::JianziLibrary* volatile library = nullptr;
volatile bool runtime_ready = false;

void prepare_runtime() {
  if (!runtime_ready) {
    __wasm_call_ctors();
    runtime_ready = true;
  }
}

int result(const nlohmann::json& value) {
  return jianzi::protocol::success(nlohmann::json::to_cbor(value));
}

int failure(const qin::JianziError& error) {
  return jianzi::protocol::error("jianzi: " + error.message);
}
}  // namespace

extern "C" __attribute__((export_name("init")))
int init(std::size_t size) {
  prepare_runtime();
  if (library) return jianzi::protocol::error("jianzi: instance is already initialized.");
  const auto data = jianzi::protocol::argument(size);
  auto loaded = qin::JianziLibrary::Load(data.data(), data.size());
  if (!loaded) return failure(*loaded.GetError());
  const auto metrics = loaded.GetValue()->GetLayoutMetrics();
  if (!std::isfinite(metrics.units_per_em) || metrics.units_per_em <= 0 ||
      !std::isfinite(metrics.baseline_y) || metrics.baseline_y < 0 ||
      metrics.baseline_y > metrics.units_per_em) {
    return jianzi::protocol::error("jianzi: baseline must lie inside the square em frame.");
  }
  library = new qin::JianziLibrary(std::move(*loaded.GetValue()));
  return jianzi::protocol::success({});
}

extern "C" __attribute__((export_name("metrics")))
int metrics() {
  prepare_runtime();
  if (!library) return jianzi::protocol::error("jianzi: instance is not initialized.");
  const auto metric = library->GetLayoutMetrics();
  const double ascent = static_cast<double>(metric.baseline_y) / metric.units_per_em;
  return result({{"advance", 1.0}, {"ascent", ascent}, {"descent", 1.0 - ascent}});
}

extern "C" __attribute__((export_name("render_natural")))
int render_natural(std::size_t size) {
  prepare_runtime();
  if (!library) return jianzi::protocol::error("jianzi: instance is not initialized.");
  const auto data = jianzi::protocol::argument(size);
  // The core takes a C string: reject embedded NUL rather than silently
  // accepting a truncated input. UTF-8 validation is done by the core.
  if (std::find(data.begin(), data.end(), 0) != data.end()) {
    return jianzi::protocol::error("jianzi: input contains a NUL byte.");
  }
  const std::string text(data.begin(), data.end());
  auto formula = library->ParseNatural(text.c_str());
  if (!formula) return failure(*formula.GetError());
  auto parsed = library->Parse(formula.GetValue()->c_str());
  if (!parsed) return failure(*parsed.GetError());
  const auto& glyph = *parsed.GetValue();
  switch (glyph.GetStatus()) {
    case qin::JianziStatus::Empty:
      return result({{"status", "empty"}});
    case qin::JianziStatus::Fallback:
      return result({{"status", "fallback"}, {"text", std::string(glyph.GetFallbackName())}});
    case qin::JianziStatus::Missing:
      return result({{"status", "missing"}, {"names", glyph.GetMissingNames()}});
    case qin::JianziStatus::Renderable:
      break;
  }
  auto paths = glyph.RenderPath();
  if (!paths) return failure(*paths.GetError());
  auto svg = jianzi::render_svg(*paths.GetValue());
  if (!svg) return failure(*svg.GetError());
  const auto& source = *svg.GetValue();
  return result({{"status", "renderable"},
                 {"svg", nlohmann::json::binary(std::vector<std::uint8_t>(source.begin(), source.end()))}});
}
