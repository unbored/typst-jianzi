#import "../jianzi.typ": init
#let case = sys.inputs.at("case")
#let base = plugin("../assets/jianzinote.wasm")
#let library = read("../assets/libraries/kai.cbor", encoding: none)
#if case == "uninitialized" {
  base.metrics()
} else if case == "invalid-cbor" {
  plugin.transition(base.init, bytes((255,)))
} else if case == "unknown-style" {
  init(style: "../kai")
} else if case == "invalid-fonts" {
  init(fallback-fonts: ())
} else if case == "missing" {
  let jianzi = init()
  jianzi("大龘")
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
