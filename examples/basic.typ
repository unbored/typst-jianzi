#import "../jianzi.typ": init
#let jianzi = init()
#set text(font: "STKaiti", size: 18pt, lang: "zh")
#set page(width: 140mm, height: auto, margin: 15mm)

减字与正文：#jianzi("大九挑七")，#jianzi("名十一抹挑六")。

#text(size: 28pt)[大号：#jianzi("大九挑七")。]

#text(baseline: 2pt)[基线调整：#jianzi("大九")。]

普通字回退：#jianzi("琴")。
