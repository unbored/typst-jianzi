#import "assets/styles.typ": bundled-styles
#import "track.typ": make-track

#let recommended-fallback-fonts = (
  "Kaiti TC", "Kaiti SC", "STKaiti", "KaiTi",
)

#let initialize-renderer(style: "kai", fallback-fonts: recommended-fallback-fonts) = {
  assert(type(style) == str, message: "jianzi: style must be a string")
  assert(style in bundled-styles, message: "jianzi: unknown style '" + style + "'")
  let fonts = if type(fallback-fonts) == str { (fallback-fonts,) } else { fallback-fonts }
  assert(type(fonts) == array, message: "jianzi: fallback-fonts must be a font name or array")
  assert(fonts.len() > 0, message: "jianzi: fallback-fonts must not be empty")
  for font in fonts {
    assert(type(font) == str and font.trim() != "", message: "jianzi: invalid fallback font name")
  }
  let base = plugin("assets/jianzinote.wasm")
  let instance = plugin.transition(
    base.init,
    read("assets/libraries/" + style + ".cbor", encoding: none),
  )
  let metrics = cbor(instance.metrics())
  let render(input) = {
    assert(type(input) == str, message: "jianzi: input must be a string")
    let result = cbor(instance.render_natural(bytes(input)))
    if result.status == "empty" {
      none
    } else if result.status == "fallback" {
      text(font: fonts, fallback: false, result.text)
    } else if result.status == "missing" {
      context {
        let em = text.size
        let stroke = 0.04em
        let warning = "[jianzi warning] " + input + ": missing components: " + result.names.join(", ")
        box(width: metrics.advance * em, height: em,
          baseline: metrics.descent * em + text.baseline)[
          // Typst has no custom warning hook; an empty font probe emits a
          // non-fatal diagnostic without adding visible text or box width.
          #text(font: warning, "")
          #place(top + left, dx: stroke / 2, dy: stroke / 2,
            rect(width: em - stroke, height: em - stroke, stroke: stroke))
          #place(top + left, dx: 0.2em, dy: 0.2em,
            line(end: (0.6em, 0.6em), stroke: stroke))
          #place(top + left, dx: 0.2em, dy: 0.8em,
            line(end: (0.6em, -0.6em), stroke: stroke))
        ]
      }
    } else if result.status == "renderable" {
      context {
        let em = text.size
        box(
          width: metrics.advance * em,
          height: em,
          baseline: metrics.descent * em + text.baseline,
          image(result.svg, format: "svg", width: em, height: em, alt: input),
        )
      }
    } else {
      panic("jianzi: unknown render status")
    }
  }
  (render: render, metrics: metrics)
}

#let init(style: "kai", fallback-fonts: recommended-fallback-fonts) = {
  initialize-renderer(style: style, fallback-fonts: fallback-fonts).render
}

// The track adapter reuses the same initialized renderer as the single-item API.
#let init-track(style: "kai", fallback-fonts: recommended-fallback-fonts, height: 2em) = {
  assert(type(height) == length, message: "jianzi: track height must be a length")
  let renderer = initialize-renderer(style: style, fallback-fonts: fallback-fonts)
  (..make-track(renderer.render, renderer.metrics.descent), height: height)
}
