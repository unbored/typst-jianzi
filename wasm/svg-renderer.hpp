#pragma once

#include <string>
#include <vector>
#include <Result.hpp>
#include <VectorPath.hpp>

namespace jianzi {
// RenderPath restores the library's original em coordinates. Font metrics
// remain in font units; units_per_em must not be used as the SVG viewBox size.
struct SvgImage {
  std::string source;
  double left;
  double top;
  double width;
  double height;
};

qin::Result<SvgImage> render_svg(const std::vector<qin::PathData>& paths);
}
