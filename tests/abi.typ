#let base = plugin("../assets/jianzinote.wasm")
#let library = cbor("../assets/libraries/kai.cbor")
#let instance = plugin.transition(base.init, cbor.encode(library))
#let metric = cbor(instance.metrics())
#assert.eq(metric.advance, 1)
#assert(calc.abs(metric.ascent - library.layout.baseline_y / library.layout.units_per_em) < 0.000001)
#assert(calc.abs(metric.ascent + metric.descent - 1) < 0.000001)
#let render(input) = cbor(instance.render_natural(bytes(input)))
#assert.eq(render(""), (status: "empty"))
#assert.eq(render(" "), (status: "empty"))
#assert.eq(render("龘"), (status: "fallback", text: "龘"))
#for name in library.glyphs.keys() {
  assert.eq(render(name).status, "renderable", message: name)
}
#let missing = render("大龘")
#assert.eq(missing.status, "missing")
#assert("龘" in missing.names)
#for input in ("大", "大九", "大九挑七", "名十一中食抹一", "(大/九)", "(大&九)", "(大|九)", "(大<九)", "(大^九)", "(大*九)", "((大/九)&七)") {
  let result = render(input)
  assert.eq(result.status, "renderable", message: input)
  assert(type(result.svg) == bytes)
  assert(str(result.svg).contains("viewBox=\"0 0 1 1\""))
  assert(str(result.svg).contains("M "))
  assert.eq(instance.render_natural(bytes(input)), instance.render_natural(bytes(input)))
}
// Two independent transitions from the same base must not share state.
// Change only the metrics and add an alias in a derived test library.
#let second-library = library
#{
  second-library.layout.baseline_y = 750
  second-library.aliases = ((alias: "探针", glyph: "大", type: "Other"),)
}
#let second = plugin.transition(base.init, cbor.encode(second-library))
#assert.eq(cbor(second.metrics()).ascent, 0.75)
#assert.eq(cbor(second.render_natural(bytes("探针"))).status, "renderable")
#assert.eq(render("探针").status, "missing")
#assert.eq(cbor(instance.metrics()), metric)
ABI and transition tests passed.
