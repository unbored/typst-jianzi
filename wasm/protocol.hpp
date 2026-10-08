#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>
#include <vector>

extern "C" {
__attribute__((import_module("typst_env"),
               import_name("wasm_minimal_protocol_write_args_to_buffer")))
void write_args(std::uint8_t* buffer);
__attribute__((import_module("typst_env"),
               import_name("wasm_minimal_protocol_send_result_to_host")))
void send_result(const std::uint8_t* buffer, std::size_t size);
}

namespace jianzi::protocol {
inline std::vector<std::uint8_t> argument(std::size_t size) {
  // A valid pointer is also provided for an empty input.
  std::vector<std::uint8_t> buffer(size + 1, 0);
  write_args(buffer.data());
  buffer.resize(size);
  return buffer;
}

inline int success(const std::vector<std::uint8_t>& data) {
  send_result(data.data(), data.size());
  return 0;
}

inline int error(std::string_view message) {
  send_result(reinterpret_cast<const std::uint8_t*>(message.data()), message.size());
  return 1;
}
}  // namespace jianzi::protocol
