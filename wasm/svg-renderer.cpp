#include "svg-renderer.hpp"

#include <cmath>
#include <iomanip>
#include <locale>
#include <sstream>

namespace jianzi {
qin::Result<std::string> render_svg(const std::vector<qin::PathData>& paths) {
  std::ostringstream out;
  out.imbue(std::locale::classic());
  out << std::setprecision(9)
      << "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1 1\">"
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
        return qin::Result<std::string>::Failure(
            {qin::JianziErrorCode::InvalidGeometry, "Unknown path command."});
    }
    if (path.pts.size() != count) {
      return qin::Result<std::string>::Failure(
          {qin::JianziErrorCode::InvalidGeometry, "Invalid path point count."});
    }
    out << command << ' ';
    for (const auto& point : path.pts) {
      if (!std::isfinite(point.x) || !std::isfinite(point.y)) {
        return qin::Result<std::string>::Failure(
            {qin::JianziErrorCode::InvalidGeometry, "Non-finite path coordinate."});
      }
      out << point.x << ' ' << point.y << ' ';
    }
  }
  out << "\"/></svg>";
  return qin::Result<std::string>::Success(out.str());
}
}  // namespace jianzi
