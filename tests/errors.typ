#import "../jianzi.typ": init, init-track
#let case = sys.inputs.at("case")
#let base = plugin("../assets/jianzinote.wasm")
#let library = read("../assets/libraries/kai.cbor", encoding: none)
#let track-cases = (
  track-five: "a[大,九,大,九,大]",
  track-reference: "g2[大,九]",
  track-empty: "a[大,]",
  track-comma: "g[大，九]",
  track-unclosed: "g[大,a[九]",
  track-nesting: "a[g[大,九]]",
  track-placeholder: "g[大,_]",
  track-old-braces: "g{大,九}",
)
#if case in track-cases {
  let adapter = init-track()
  (adapter.parse)(track-cases.at(case))
} else if case == "uninitialized" {
  base.metrics()
} else if case == "invalid-cbor" {
  plugin.transition(base.init, bytes((255,)))
} else if case == "unknown-style" {
  init(style: "../kai")
} else if case == "invalid-fonts" {
  init(fallback-fonts: ())
} else {
  let instance = plugin.transition(base.init, library)
  if case == "invalid-utf8" {
    instance.render_natural(bytes((255,)))
  } else if case == "nul" {
    instance.render_natural(bytes((0,)))
  } else if case == "invalid-formula" {
    instance.render_natural(bytes("(大/)"))
  } else if case == "reinit" {
    plugin.transition(instance.init, library)
  } else {
    panic("unexpected test case")
  }
}
