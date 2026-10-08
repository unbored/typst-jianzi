#let library = cbor("../assets/libraries/kai.cbor")
#metadata((
  format: library.format,
  version: library.format_version,
  layout: library.at("layout", default: (:)),
  glyphs: library.glyphs.keys(),
  aliases: library.at("aliases", default: ()).map(a => a.alias),
  sample: library.glyphs.at("大"),
)) <library>
