// This module has no dependency on a score renderer. Its items are opaque
// data until render-item produces a complete box and a local horizontal anchor.
#let parse-member(source) = {
  let source = source.trim()
  assert(source != "", message: "jianzi track: empty group member")
  assert(not source.contains("，"), message: "jianzi track: use ASCII commas")
  if source.starts-with("a{") or source.match(regex("^g[0-9]*\\{")) != none {
    assert(source.ends-with("}"), message: "jianzi track: unclosed group")
    let opening = source.position("{")
    let prefix = source.slice(0, opening)
    let inner = source.slice(opening + 1, source.len() - 1)
    let members = ()
    let buffer = ""
    let depth = 0
    for character in inner.clusters() {
      if character == "{" { depth += 1 }
      if character == "}" { depth -= 1 }
      assert(depth >= 0, message: "jianzi track: unmatched closing brace")
      if character == "," and depth == 0 {
        members.push(parse-member(buffer))
        buffer = ""
      } else { buffer += character }
    }
    assert(depth == 0, message: "jianzi track: unclosed nested group")
    members.push(parse-member(buffer))
    if prefix == "a" {
      assert(members.len() <= 4, message: "jianzi track: annotations allow at most four members")
      assert(members.all(member => member.kind == "normal"),
        message: "jianzi track: annotation members must be single characters or jianzi")
      (kind: "annotation", members: members)
    } else {
      assert(members.all(member => member.kind in ("normal", "annotation")),
        message: "jianzi track: horizontal groups cannot contain other horizontal groups")
      let reference = if prefix == "g" { 0 } else { int(prefix.slice(1)) }
      assert(reference < members.len(), message: "jianzi track: reference index out of range")
      (kind: "horizontal", members: members, reference: reference)
    }
  } else {
    assert(not source.contains(regex("[{},\\s]")), message: "jianzi track: invalid member syntax")
    assert(source != "_" and source != "|", message: "jianzi track: placeholders are only allowed at top level")
    (kind: "normal", text: source)
  }
}

#let parse-track(source) = {
  assert(type(source) == str, message: "jianzi track: source must be a string")
  let tokens = ()
  let buffer = ""
  let depth = 0
  for character in source.clusters() {
    if character == "{" { depth += 1 }
    if character == "}" { depth -= 1 }
    assert(depth >= 0, message: "jianzi track: unmatched closing brace")
    if character.contains(regex("\\s")) and depth == 0 {
      if buffer != "" { tokens.push(buffer); buffer = "" }
    } else { buffer += character }
  }
  assert(depth == 0, message: "jianzi track: unclosed group")
  if buffer != "" { tokens.push(buffer) }
  tokens.filter(token => token != "|").map(token => {
    if token == "_" { none } else { parse-member(token) }
  })
}

#let make-track(render, descent) = {
  // All outputs have this fixed height, even a half-height annotation. The
  // score renderer scales the whole box; it must not trim its empty upper half.
  let unit = 20pt
  let horizontal-gap = unit * 0.08
  let vertical-gap = unit * 0.04

  let render-member(data) = {
    if data.kind == "normal" {
      // Use the renderer's em cell, not each fallback glyph's ink bounds.
      // Otherwise shorter glyphs are enlarged and no longer match the SVG size.
      let content = text(size: unit, weight: "regular", baseline: 0pt,
        top-edge: unit * (1 - descent), bottom-edge: -unit * descent)[#render(data.text)]
      let bounds = measure(content)
      assert(bounds.width > 0pt and bounds.height > 0pt,
        message: "jianzi track: a member must render non-empty content")
      let factor = unit / bounds.height
      let width = bounds.width * factor
      (
        body: box(width: width, height: unit, baseline: 0pt,
          scale(factor * 100%, origin: top + left, reflow: true, content)),
        anchor-x: width / 2,
      )
    } else if data.kind == "annotation" {
      let members = data.members.map(render-member)
      let count = members.len()
      let member-height = if count == 1 { unit / 2 } else {
        (unit - vertical-gap * (count - 1)) / count
      }
      let factor = member-height / unit
      let widths = members.map(member => measure(member.body).width * factor)
      let width = calc.max(..widths)
      let body = box(width: width, height: unit, baseline: 0pt)[
        #for (index, member) in members.enumerate() {
          let offset-y = if count == 1 { unit / 2 } else {
            index * (member-height + vertical-gap)
          }
          place(top + left, dx: (width - widths.at(index)) / 2, dy: offset-y,
            scale(factor * 100%, origin: top + left, reflow: true, member.body))
        }
      ]
      (body: body, anchor-x: width / 2)
    } else {
      assert(data.kind == "horizontal", message: "jianzi track: invalid item kind")
      let members = data.members.map(render-member)
      let widths = members.map(member => measure(member.body).width)
      let width = widths.fold(0pt, (total, value) => total + value) + horizontal-gap * (members.len() - 1)
      let anchor = 0pt
      let body = box(width: width, height: unit, baseline: 0pt)[
        #let offset-x = 0pt
        #for (index, member) in members.enumerate() {
          place(top + left, dx: offset-x, member.body)
          offset-x += widths.at(index) + horizontal-gap
        }
      ]
      for index in range(data.reference) { anchor += widths.at(index) + horizontal-gap }
      anchor += members.at(data.reference).anchor-x
      (body: body, anchor-x: anchor)
    }
  }

  (parse: parse-track, render-item: render-member)
}
