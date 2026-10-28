#include "svg-renderer.hpp"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <locale>
#include <sstream>

namespace jianzi {
qin::Result<SvgImage> render_svg(const std::vector<qin::PathData>& paths) {
  double left = 0.0;
  double top = 0.0;
  double right = 1.0;
  double bottom = 1.0;
  for (const auto& path : paths) {
    for (const auto& point : path.pts) {
      if (!std::isfinite(point.x) || !std::isfinite(point.y)) {
        return qin::Result<SvgImage>::Failure(
            {qin::JianziErrorCode::InvalidGeometry, "Non-finite path coordinate."});
      }
      left = std::min(left, static_cast<double>(point.x));
      top = std::min(top, static_cast<double>(point.y));
      right = std::max(right, static_cast<double>(point.x));
      bottom = std::max(bottom, static_cast<double>(point.y));
    }
  }
  // Bezier curves stay inside their control-point hull. Expand only the SVG
  // viewport; the caller preserves the em cell and offsets the larger image.
  const double width = right - left;
  const double height = bottom - top;
  std::ostringstream out;
  out.imbue(std::locale::classic());
  out << std::setprecision(9)
      << "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\""
      << left << ' ' << top << ' ' << width << ' ' << height << "\">"
      << "<path fill=\"#000\" fill-rule=\"nonzero\" d=\"";
  for (const auto& path : paths) {
    std::size_t count = 0;
    char command = 'Z';
    switch (path.key) {
      case qin::PathKey::MoveTo: command = 'M'; count = 1; break;
      case qin::PathKey::LineTo: command = 'L'; count = 1; break;
      case qin::PathKey::QuadTo: command = 'Q'; count = 2; break;
      case qin::PathKey::CubicTo: command = 'C'; count = 3; break;
      case qin::PathKey::Close: break;
      default:
        return qin::Result<SvgImage>::Failure(
            {qin::JianziErrorCode::InvalidGeometry, "Unknown path command."});
    }
    if (path.pts.size() != count) {
      return qin::Result<SvgImage>::Failure(
          {qin::JianziErrorCode::InvalidGeometry, "Invalid path point count."});
    }
    out << command << ' ';
    for (const auto& point : path.pts) {
      if (!std::isfinite(point.x) || !std::isfinite(point.y)) {
        return qin::Result<SvgImage>::Failure(
            {qin::JianziErrorCode::InvalidGeometry, "Non-finite path coordinate."});
      }
      out << point.x << ' ' << point.y << ' ';
    }
  }
  out << "\"/></svg>";
  return qin::Result<SvgImage>::Success({out.str(), left, top, width, height});
}
}  // namespace jianzi
