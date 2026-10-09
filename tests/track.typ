#import "../jianzi.typ": init-track

#set page(width: 160mm, height: auto, margin: 12mm)
#set text(font: "STKaiti", size: 16pt)
#let adapter = init-track(fallback-fonts: ("STKaiti", "KaiTi"))
#assert.eq(adapter.height, 2em)
#assert.eq(init-track(height: 1.8em).height, 1.8em)
#assert.eq(init-track(height: 24pt).height, 24pt)
#let parse = adapter.parse
#let render-item = adapter.render-item
#let items = parse("大九 a[琴] a[大九,琴,九,甲] g1[大九,a[琴,九]] _ | g[琴,大九]")
#assert.eq(items.len(), 6)
#assert.eq(items.at(4), none)
#assert.eq(items.at(3).reference, 1)
#assert.eq(items.at(5).reference, 0)
#assert.eq(parse("g[ 大九, a[ 琴, 九 ] ]\n_ | 九").len(), 3)

#context {
  let rendered = items.filter(item => item != none).map(render-item)
  for item in rendered {
    let bounds = measure(item.body)
    assert.eq(bounds.height, 20pt)
    assert(item.anchor-x > 0pt and item.anchor-x < bounds.width)
  }
  let normal = render-item(parse("大九").first())
  let missing = render-item(parse("大龘").first())
  assert.eq(measure(missing.body), measure(normal.body))
  for source in ("a[大龘]", "a[大九,大龘]", "g1[大九,大龘]") {
    let item = render-item(parse(source).first())
    assert.eq(measure(item.body).height, 20pt)
    item.body
  }
  for source in ("琴", "甲") {
    let fallback = render-item(parse(source).first())
    assert.eq(measure(fallback.body).width, measure(normal.body).width)
  }
  let mixed = render-item(parse("g[大九,琴]").first())
  assert.eq(measure(mixed.body).width, 20pt * 2 + 20pt * 0.08)
  let annotation = render-item(parse("a[大九]").first())
  assert.eq(measure(annotation.body).width, measure(normal.body).width / 2)
  let first = render-item(parse("g[大九,琴]").first())
  let second = render-item(parse("g1[大九,琴]").first())
  assert.eq(measure(first.body).width, measure(second.body).width)
  assert(second.anchor-x > first.anchor-x)
  for source in (
    "a[大九,九]", "a[大九,九,大九]", "a[大九,九,大九,九]",
    "a[琴,甲]", "a[琴,甲,琴]", "a[琴,甲,琴,甲]",
  ) {
    let item = render-item(parse(source).first())
    assert.eq(measure(item.body).height, 20pt)
  }
  stack(dir: ttb, spacing: 8pt, ..rendered.map(item => item.body))
}
