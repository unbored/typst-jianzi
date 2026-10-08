#import "../jianzi.typ": init
#set page(width: 160mm, height: auto, margin: 12mm)
#set text(font: "STKaiti", size: 16pt, lang: "zh")
#let jianzi = init()

普通文字与减字：大 #jianzi("大") 九 #jianzi("九")，
组合 #jianzi("大九") #jianzi("大九挑七") #jianzi("名十一中食抹一")。

#text(size: 10pt)[小号文字 #jianzi("大九挑七")。]

#text(size: 28pt)[大号文字 #jianzi("大九挑七")。]

基线调整：大 #jianzi("大")
#text(baseline: 3pt)[大 #jianzi("大")]
#text(baseline: -3pt)[大 #jianzi("大")]。

Fallback：#text(fill: red)[#jianzi("琴")]；空输入：甲#jianzi("")乙。

#table(
  columns: 3,
  [自然输入], [公式兼容], [Fallback],
  jianzi("大九挑七"), jianzi("(大/九)"), jianzi("琴"),
)

#context {
  assert.eq(measure(jianzi("大九")).width, text.size)
  assert.eq(measure(jianzi("大九")).height, text.size)
  assert.eq(measure(jianzi("")).width, 0pt)
}
#text(size: 1.5em)[#context {
  assert.eq(measure(jianzi("大九")).width, text.size)
}]
