#import "assets/styles.typ": bundled-styles

#let recommended-fallback-fonts = (
  "Kaiti TC", "Kaiti SC", "STKaiti", "KaiTi",
)

#let init(style: "kai", fallback-fonts: recommended-fallback-fonts) = {
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
      panic("jianzi: missing components: " + result.names.join(", "))
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
  render
}
