# typst-jianzi

将 JianziNote 编译成 WASM，在 Typst 文档中生成单个内联减字。第一版仅支持自然输入（含自然解析器兼容的公式）、固定黑色 SVG，以及初始化时配置的普通字符 fallback 字体。

## 构建

需要 CMake 3.21+、Ninja、Emscripten、vcpkg、wasi-stub，以及用于验证的 Typst 0.13+。先初始化子模块，并将外部产出的 StrokeDesc v2 字库放入 `assets/libraries/<style>.cbor`；至少需要 `kai.cbor`。

本机 PowerShell 示例：

```powershell
git submodule update --init --recursive
./scripts/build.ps1 -Emsdk D:/tools/emsdk -VcpkgRoot D:/vcpkg `
  -WasiStub D:/tools/wasi-stub/wasi-stub.exe -Typst D:/tools/typst/typst.exe
```

脚本自动设置 SDK 的 Python、Node 和工具链环境变量，依次配置、编译、执行 wasi-stub、检查导入、运行 Typst 测试。需要只构建时可使用 `-SkipTests`。也可以设置 `EMSDK`、`EMSCRIPTEN_ROOT`、`EMSDK_PYTHON`、`EMSDK_NODE`、`VCPKG_ROOT`、`WASI_STUB`、`TYPST` 后直接使用 `cmake --preset wasm-release`、`cmake --build --preset wasm-release`、`ctest --preset wasm-release`。

最终产物是 `assets/jianzinote.wasm` 和自动生成的 `assets/styles.typ`；原始 WASM 保存在 `build/wasm-release/wasm/`。最终 WASM、字库和风格表均由本地或发布流程提供，暂不提交 Git。可以通过 `-DJIANZI_LIBRARY_DIR=<目录>` 从另一个指定目录组装包内字库，公开 Typst API 仍只允许选择包内风格。

## 使用

```typst
#import "jianzi.typ": init
#let jianzi = init(style: "kai")
#set text(size: 16pt)

正文 #jianzi("大九挑七")，#jianzi("名十一中食抹一")。
#jianzi("(大/九)") // 公式使用完整的外层括号
#text(size: 24pt)[#jianzi("大九")]
#text(baseline: 2pt)[#jianzi("大九")]
```

`init()` 默认使用 `kai` 和导出的 `recommended-fallback-fonts`。`fallback-fonts` 支持一个字体名或非空列表，自定义值完整替换默认列表。字体需要安装在 Typst 运行环境中，不随包提供。

默认 fallback 顺序是 `Kaiti TC`（华文楷体繁体）→ `Kaiti SC`（华文楷体简体）→ `STKaiti`（Windows/Office 华文楷体）→ `KaiTi`（Windows 楷体）。需要自定义时，例如 `init(fallback-fonts: ("STKaiti", "KaiTi"))`。

公式兼容遵循 JianziNote 自然解析器的约定：整个输入用一对外层括号包住，例如 `"(大/九)"`；没有完整外层括号的字符串按自然输入处理。

渲染函数只接收一个字符串：空输入返回 `none`；可渲染减字返回一个随当前字号缩放的方形 inline box；单个未知字符用配置字体显示普通文本；组合中的未知部分报错并列出名称。减字采用参考字体的固定基线和 1em 字位，用户调整使用普通的 `text(size: ...)` 和 `text(baseline: ...)`。SVG 为黑色，fallback 文本会继承文字颜色。内联图片不参与字体连字、字距等 shaping。

编译示例：

```powershell
D:/tools/typst/typst.exe compile --root . examples/basic.typ build/basic.pdf
```

## 打包

```powershell
cmake --install build/wasm-release --prefix build/package
```

打包目录包含 Typst 入口、清单、许可证、处理后的 WASM、风格表和 CBOR。源码子模块和中间产物不进入包。字库风格名使用小写 ASCII 字母、数字、`-`、`_`，以字母开头；增加字库后重新构建会更新白名单。

架构约定与限制见 [docs/architecture.md](docs/architecture.md)。

本机已通过 Typst 0.14.2 的完整集成测试，以及官方 Typst 0.13.0 的 ABI、内联排版和打包入口验证。Web App 与其他平台仍待验证。
