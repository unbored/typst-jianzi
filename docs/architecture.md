# typst-jianzi 架构设计草案

> 状态：讨论稿，尚未进入实现阶段。
>
> 本文记录当前共识、已确认设计和待决问题。标为“初步决定”的内容仍可在实现前修改。

## 1. 项目目标

本项目将 JianziNote 的 C++ 减字生成能力编译为 WebAssembly，并将其包装为可在 Typst 中直接使用的包。

预期调用链为：

```text
Typst 用户 API：init(style, fallback-fonts) / jianzi(text)
    │
    │ 内置风格名、UTF-8 自然输入
    ▼
Typst 包装层（jianzi.typ）
    │
    ├── 读取与风格对应的包内 CBOR
    │
    │ bytes / plugin.transition
    ▼
Typst WASM minimal protocol
    │
    ▼
JianziNote C++ 核心
    │
    │ PathData
    ▼
SVG 输出适配层
    │
    │ SVG bytes
    ▼
Typst image
```

本包只解决“在 Typst 文档中生成并排版单个减字”的问题。减字作为内联对象，与普通文字共同参与段落排版。琴谱级布局、连接线、节奏和整页排版不属于本项目范围。

## 2. 设计原则

1. **JianziNote 保持通用。** 核心库不引入 Typst 专属协议或 Typst 排版概念。
2. **WASM 层尽量薄。** 它只负责参数解码、调用 JianziNote、结果编码和错误转换。
3. **Typst 层提供稳定 API。** 用户只选择内置字库风格并提交自然输入，不直接操作插件的 bytes 接口。
4. **先打通最短链路。** 第一版采用 SVG 输出，不在 Typst 中重新实现 `PathData` 渲染。
5. **构建可复现。** 发布包中的 `.wasm` 应能从指定的 JianziNote 提交和工具链重新生成。
6. **遵守纯函数约束。** 同样的输入必须产生同样的输出；不能依赖文件系统、网络、时间或跨调用的隐式可变状态。

## 3. 已有基础

JianziNote 已经具备适合 WASM 封装的内存接口：

```cpp
static Result<JianziLibrary> Load(const std::uint8_t* data, std::size_t size);
LayoutMetrics GetLayoutMetrics() const;
Result<Jianzi> Parse(const char* u8_str) const;
Result<std::string> ParseNatural(const char* u8_str) const;
Result<std::vector<PathData>> RenderPath() const;
```

因此插件不需要文件系统访问，也不需要另建一套 CBOR 解析 API。WASM 适配层可以直接把 Typst 传入的字节交给 `JianziLibrary::Load`。

核心库已经全面采用 C++17 `Result<T>`/`JianziError`，并以 `-fno-exceptions` 和 `JSON_NOEXCEPTION` 构建。`JianziErrorCode` 覆盖 CBOR、字库、UTF-8、公式、别名循环、StrokeDesc、几何和上下文错误。插件层只需把失败结果转换为 minimal protocol error。

解析结果还提供 `JianziStatus`：

```text
Empty       空输入
Renderable  可生成路径
Fallback    单个未知字符，可交给正常字体回退
Missing     组合减字中存在无法生成的组成部分
```

JianziNote 现有的 `Jianzi2Svg` 可作为 SVG 序列化行为的参考。是否直接复用其 `SvgRenderer`，需要在检查其输出尺寸、颜色和依赖后决定。

## 4. 仓库边界

初步建议的目录结构如下：

```text
typst-jianzi/
├── JianziNote/              # Git submodule：通用 C++ 核心
├── docs/
│   └── architecture.md      # 本文
├── wasm/                    # Typst WASM 适配层
│   ├── CMakeLists.txt
│   ├── plugin.cpp           # minimal protocol 导出函数
│   ├── protocol.hpp         # 协议辅助代码
│   └── svg-renderer.cpp     # PathData 到 SVG
├── assets/
│   ├── jianzinote.wasm      # 随 Typst 包发布的构建产物
│   └── libraries/           # 由外部字库生产流程提供
│       ├── kai.cbor          # 默认风格
│       └── <style>.cbor      # 文件名（不含扩展名）就是风格名
├── tests/
│   ├── smoke.typ
│   └── natural.typ
├── examples/
│   └── basic.typ
├── jianzi.typ               # Typst 包入口和公开 API
├── typst.toml
├── CMakeLists.txt           # 顶层 WASM 构建入口
├── README.md
└── LICENSE
```

这只是目标结构，不要求在实现开始前创建所有空目录。

### 4.1 JianziNote 子模块

子模块固定到经过验证的提交。插件构建默认关闭以下内容：

- FreeType 字体读取器；
- 命令行工具；
- 与 WASM 目标无关的原生可执行文件。

如果编译 WASM 所需的改动属于通用能力，应优先提交到 JianziNote；只有协议胶水和 Typst 特有输出逻辑留在本仓库。

### 4.2 发布物与中间产物

`assets/jianzinote.wasm` 是 Typst 包运行所需的发布物，应随包分发，但当前不提交到源码 Git 仓库。CMake 构建目录、对象文件和未优化的中间 WASM 不进入发布包。

字库由本项目以外的流程产出，并以一个目录交付给本项目。目录中的文件使用 `<style>.cbor` 命名，文件名去掉扩展名后就是公开风格名；默认风格为 `kai`，对应 `assets/libraries/kai.cbor`。这些字库与插件一起发布，但当前同样不提交到源码 Git 仓库。本项目不提供字库编辑或生成工具，也不接受用户指定任意路径或任意 CBOR 数据。

第一版不另行设计制品校验、校验和或签名机制，默认交付目录中的字库是可信且与当前 JianziNote 兼容的。加载时仍由 `JianziLibrary::Load` 执行已有的 CBOR 结构和格式版本检查。

当前策略是源码仓库不跟踪最终 WASM 和 CBOR，由本地打包或发布/CI 流程将二者组装进 Typst 包。`.gitignore` 应明确忽略 `assets/jianzinote.wasm` 和 `assets/libraries/*.cbor`。WASM 必须能在 CI 中从源码重建；CBOR 则由独立字库流程或 CI artifact 提供。这是可修改的暂定决策，日后确定正式发布流程时再评估是否将制品纳入 Git。

## 5. WASM 接口

### 5.1 第一版接口

WASM 模块导出初始化、度量和渲染函数：

```text
init(library_cbor: bytes) -> empty bytes
metrics() -> metrics_cbor: bytes
render_natural(text_utf8: bytes) -> render_result_cbor: bytes
```

初始化行为：

1. Typst 包装层验证 `style` 是随包发布的已知风格，默认值为 `kai`；
2. 根据固定规则定位 `assets/libraries/<style>.cbor`；
3. Typst 包装层读取该文件，并通过 `plugin.transition` 调用 `init`；
4. `init` 从 CBOR 构造 `JianziLibrary`，保存到派生插件实例的线性内存；
5. 原始插件实例保持未初始化，因此可从同一模块派生不同风格的实例。

渲染行为：

1. 将 `text_utf8` 交给 `JianziLibrary::ParseNatural`；
2. 将得到的公式交给 `JianziLibrary::Parse`；
3. 调用 `RenderPath()`；
4. 将路径序列化为完整 SVG；
5. 根据 `JianziStatus` 返回带状态的 CBOR；`Renderable` 的 payload 为 UTF-8 SVG 字节。

建议的渲染结果结构为：

```text
(status: "empty")
(status: "renderable", svg: bytes)
(status: "fallback", text: str)
(status: "missing", names: array<str>)
```

这些状态是成功解析后的语义结果，不等同于 `JianziError`。真正的加载、UTF-8、公式或几何错误仍通过 minimal protocol error 返回。

Typst 包装层对四种状态做固定处理：

- `Empty`：返回 `none`；
- `Renderable`：按参考字体度量返回内联 SVG；
- `Fallback`：将 `text` 作为普通 Typst 文本，使用 `init` 时配置的 fallback 字体渲染；
- `Missing`：报错并列出 `names` 中无法生成的组成部分。

fallback 字体是 Typst 排版配置，不进入 WASM 状态或 ABI。WASM 只返回需要 fallback 的原字符文本。

`init` 不作为允许用户传入任意字库的公开 API。公开的 `init(style: "kai", fallback-fonts: recommended-fallback-fonts)` 中，`style` 只接受随包提供的风格名称，`fallback-fonts` 则只是 Typst 层的文字排版配置。实现可以在构建或打包时根据字库目录生成风格白名单；不能把未经验证的用户字符串直接拼接为读取路径。

由于 Typst WASM 插件不能访问文件系统，WASM 中的 `init` 不能根据路径自行读取 CBOR。“内部读取特定字库”具体指 Typst 包装层读取包内固定资源，再把 bytes 传给 WASM 初始化函数；文件路径和原始 bytes 都不向用户开放。

插件错误通过 minimal protocol 的错误返回值传递，并使用 UTF-8 文本描述。WASM 可达路径不能依赖 C++ 异常传播或捕获，具体策略见下文“错误处理”。

Typst 的 transition 目前只保证派生实例继承 WASM 线性内存中的修改，不保证 WASM globals。插件的已初始化状态必须存放在线性内存中，技术探针需要专门验证 C++ 对象生命周期。

`plugin.transition` 从 Typst 0.13.0 开始提供，因此本包的最低 Typst 版本固定为 `0.13.0`。未来的 `typst.toml` 应声明相同的 compiler 版本下限。

`metrics()` 在初始化后调用，返回当前风格的内联排版度量。现有 CBOR 字段已经足够：`units_per_em` 给出 em 尺度，`baseline_y` 给出参考字体基线在方形 em 字位中的位置。减字采用全角方形字位，因此横向 advance 固定为 `1em`，不需要新增 advance、ascender 或 descender 字段。

Typst 所需度量可直接推导为：

```text
advance = 1
ascent  = baseline_y / units_per_em
descent = 1 - ascent
```

这里假定 `baseline_y` 使用从 em 方框顶部向下的坐标，与当前默认值 `880 / 1000` 的语义一致。Typst 层只消费这些以 em 为单位的比例，不直接依赖 JianziNote 的内部坐标或 glyph normalization。

度量和轮廓都以该风格的参考字体为准。`metrics()` 不根据某个减字的实际轮廓边界动态计算占位，而是返回参考字体的稳定字体度量，使同一字号下的减字与参考字体文字拥有一致的基线和字位行为。

### 5.2 可选的诊断接口

```text
version() -> version_utf8
```

除非调试、兼容性检查或错误报告确有需要，否则第一版不增加该接口。避免把 JianziNote 的每个 C++ 方法逐一映射为插件函数。

### 5.3 暂不采用 PathData 作为返回值

另一种方案是把 `PathData` 编码为 CBOR，再由 Typst 侧绘制。它能让 Typst 更自由地控制填充色和路径组合，但也会引入：

- 一套需要长期兼容的路径序列化格式；
- Typst 侧的路径解释和渲染代码；
- 更多跨 WASM 边界的数据；
- 与 JianziNote 其他 SVG 输出端重复的逻辑。

因此第一版优先返回 SVG。若 SVG 难以满足颜色、基线或组合排版需求，再重新评估结构化路径输出。

### 5.4 错误处理

JianziNote 已完成全面无异常改造。内部以 `Result<T>` 显式传播失败：

```text
init(bytes)
  → cbor::Read
  → JianziLibrary::Load
  → 成功后提交实例状态

render_natural(text)
  → JianziLibrary::ParseNatural
  → JianziLibrary::Parse
  → 检查 JianziStatus
  → Jianzi::RenderPath（仅 Renderable）
  → SVG 序列化
  → protocol success/error
```

`Result<T>` 以 `std::variant<T, JianziError>` 实现，访问器返回指针，不会因读取错误分支而抛异常。CBOR 使用 `from_cbor(..., allow_exceptions = false)`；UTF-8 先验证，再使用 unchecked 转换。源码中已无 `throw`、`try` 或 `catch`。

CMake 的 `JianziNoExceptions` interface target 向 JianziNote 及其调用方传播：

```text
JSON_NOEXCEPTION
-fno-exceptions              # Clang/GCC/Emscripten
/EHs-c- + _HAS_EXCEPTIONS=0 # MSVC
```

WASM 导出层的责任缩减为：

1. 将失败的 `JianziError::message` 作为 minimal protocol error 返回；
2. `init` 只在 `Load` 成功后提交插件实例状态；
3. 在调用 `RenderPath` 前处理 `JianziStatus`，不能把 Empty、Fallback 或 Missing 静默变成空白 SVG；
4. 内存耗尽、越界访问和内部不变量破坏等不可恢复故障仍允许成为 WASM trap。

`JianziErrorCode` 是核心库内部的稳定分类；第一版不必把它固化为 Typst 侧机器可读 ABI。若只需编译诊断，向用户返回 `message` 即可。

## 6. 字库加载策略

正式方案采用包内固定字库和 `plugin.transition` 初始化：

```text
公开 style 名称
    → Typst 内部风格白名单
    → assets/libraries/<style>.cbor
    → read(..., encoding: none)
    → plugin.transition(base.init, library-bytes)
    → 已初始化的风格实例
```

约束如下：

- 字库由独立流程以指定目录产出，本仓库只消费成品；
- 所有支持的字库随 Typst 包一起发布；
- 用户不能传入 CBOR bytes、文件路径或 URL；
- 未知风格名在 Typst 层直接报错；
- 风格名与 CBOR 文件名一致，默认风格为 `kai`；
- 每个派生插件实例只初始化一次，并固定使用一种风格；
- 字库格式版本不兼容时，初始化立即失败；
- 第一版不增加字库制品的额外完整性校验。

这种设计避免每次渲染重复传输和解析字库，同时让字库生产与插件源码保持独立。

## 7. Typst 公开 API 草案

底层插件对象和字库资源不直接导出给用户。第一版 Typst API 采用显式初始化：

```typst
#import "jianzi.typ": init

#let jianzi = init() // 等价于 init(style: "kai")

#jianzi("大九")

#text(size: 1.2em)[#jianzi("大九")]
#text(baseline: 1pt)[#jianzi("大九")]
```

`init` 返回绑定到指定风格插件实例的渲染函数。`style` 的默认值固定为 `kai`。

fallback 字体在初始化时指定：

```typst
#let jianzi = init(
  style: "kai",
  fallback-fonts: ("KaiTi", "Noto Serif CJK SC"),
)
```

`fallback-fonts` 接受单个字体名或非空字体名数组；单个名称在内部归一化为数组。用户传入时完全替换默认列表，不与默认值隐式合并。包导出 `recommended-fallback-fonts`，并将它作为 `init` 的默认值。首版推荐列表暂定为：

```typst
#let recommended-fallback-fonts = (
  "FandolKai",
  "KaiTi",
  "Kaiti SC",
  "STKaiti",
  "Noto Serif CJK SC",
  "Source Han Serif SC",
)
```

顺序表示优先级，前面的字体不可用或不含目标字符时才尝试后续字体。这些字体不随包附带，实际可用性取决于 Typst 运行环境；发布前应在 Windows、macOS 和常见 Linux/Typst 环境验证字体族名，再固定顺序。

公开 API 仅使用自然输入。减字公式本身由自然输入解析器兼容，因此不再提供单独的公式模式、布尔开关或第二个渲染函数。

### 7.1 内联排版目标

`jianzi()` 返回 `box(image(...))`，而不是独立的块级图片。减字需要像一个方形文字字形一样参与断行、行高和基线对齐。

`jianzi()` 不公开 `size` 或 `baseline` 参数，只接收自然输入：

```typst
#jianzi("大九")
```

- 字号从调用位置的 `text.size` 上下文读取，减字的 em 尺寸与当前文字字号一致；
- 用户通过普通 Typst 文字样式调整字号，例如 `#set text(size: 14pt)` 或 `#text(size: 1.2em)[...]`；
- 额外基线偏移同样从 `text.baseline` 上下文读取，因此 `#set text(baseline: ...)` 和 `#text(baseline: ...)[...]` 对减字使用与普通文字相同的写法；
- 横向 advance 固定为当前字号的 `1em`；ascent 和 descent 由 `baseline_y / units_per_em` 划分，不根据实际减字轮廓收紧；
- SVG viewBox 表示恢复后的参考字体 em 坐标，Typst 按当前字号和 advance 比例设置图片及外层 box 的尺寸；
- 图片的替代文本使用调用者提供的自然输入。

Typst 的 `image` 是块级元素，必须放进 `box` 才能嵌入段落。实现使用 `context` 读取 `text.size` 和 `text.baseline`，再用 `box` 的内部 `baseline` 设置同时合并参考字体的基线位置与当前文字样式的额外偏移。这个 `box.baseline` 是包内实现细节，不是 `jianzi()` 的公开参数。

`Fallback` 不创建 SVG 或 `box`，而是返回类似 `text(font: fallback-fonts, fallback: false)[fallback-text]` 的真实文本。这样它会自然继承调用处的字号、基线、颜色和其他文字样式，同时将字体选择限定在初始化时给定的列表中。

JianziNote 字库已经包含所需的 `units_per_em` 和 `baseline_y`。`baseline_y` 是原始参考字体的参数，不是根据归一化设计空间或某个减字的实际边界推导出来的值。WASM 的 `metrics()` 负责把它换算为 Typst 所需的基线比例。为此需要给 `JianziLibrary` 增加只读的度量访问接口，但不需要修改 CBOR 格式或增加字段。

### 7.2 参考字体与设计坐标

每种减字风格以一个现成字体文件作为参考，其排版度量与该字体对齐。字形设计采用以下坐标流程：

1. 统计参考字体中常用 GB2312 汉字的实际轮廓范围；
2. 使用统一变换将统计范围按长边等比缩放到 `0..1`；
3. 将短边在 `0..1` 范围内居中；
4. 在这个归一化设计空间中定义和组合减字；
5. 在最终合成结束后应用所记录平移、缩放的逆变换，恢复到参考字体坐标；
6. 使用参考字体的 em、基线和 advance 将结果嵌入 Typst 文本行。

归一化变换是字库内部实现细节，不能改变最终排版度量。Typst 侧也不能用减字的 tight bounding box 重新缩放或居中，否则不同减字会在同一行中产生不一致的视觉字号和基线。

当前 `RenderPath()` 已按 `(point - translate) / scale` 恢复字库记录的 glyph normalization。实现阶段需要用参考字体样本验证恢复后的坐标范围，并据此修改 SVG viewBox；现有 `SvgRenderer` 固定使用 `viewBox="0 0 1 1"`，只有在恢复后的 em 坐标仍以 `0..1` 表示时才可原样复用。

## 8. SVG 输出要求

第一版 SVG 至少需要满足：

- 确定的 `viewBox`；
- 不依赖外部 CSS、字体、文件或网络；
- 坐标和浮点数输出稳定；
- 同样输入产生逐字节一致的结果；
- 能在 Typst CLI 和 Typst Web App 中加载；
- 尺寸缩放后不改变笔画比例；
- 错误输入不生成部分或损坏的 SVG。

第一版 SVG 使用固定颜色，WASM 和 Typst API 均不传递颜色参数。颜色定制不属于当前设计范围；若以后出现明确需求，再单独设计，避免首版 ABI 提前承担该兼容性约束。

## 9. 构建约束

Typst 插件是 32 位 WebAssembly 模块，并需要实现 minimal protocol。最终模块只能依赖 Typst 插件宿主允许的导入。

初步决定采用 Emscripten，并通过 vcpkg 的 community triplet 管理 C++ 依赖。当前本地开发环境已经具备：

```text
D:\tools\emsdk
└── upstream/emscripten       # Emscripten 6.0.10

D:\vcpkg
└── triplets/community/wasm32-emscripten.cmake

D:\tools\wasi-stub
└── wasi-stub.exe          # wasi-stub 0.3.1
```

当前 vcpkg 版本为 `2025-10-16`。上述绝对路径只描述本机环境，不写死在 CMake 项目中。构建入口通过环境变量定位工具链：

```text
EMSDK=D:\tools\emsdk
EMSCRIPTEN_ROOT=D:\tools\emsdk\upstream\emscripten
VCPKG_ROOT=D:\vcpkg
WASI_STUB=D:\tools\wasi-stub\wasi-stub.exe
```

community triplet 会把
`$EMSCRIPTEN_ROOT/cmake/Modules/Platform/Emscripten.cmake` 设为 vcpkg 的
chainload toolchain，因此 CMake 只应设置 vcpkg toolchain，不再同时传入第二个
`CMAKE_TOOLCHAIN_FILE`。CMake preset 预计设置：

```text
CMAKE_TOOLCHAIN_FILE=D:/vcpkg/scripts/buildsystems/vcpkg.cmake
VCPKG_TARGET_TRIPLET=wasm32-emscripten
```

根项目应提供自己的 `vcpkg.json`，第一阶段只声明：

```json
{
  "dependencies": [
    "nlohmann-json",
    "utfcpp"
  ]
}
```

不能直接继承 JianziNote manifest 的默认 feature：它默认启用 `font-reader` 并引入 FreeType，而 WASM 插件不需要字体读取器。配置 JianziNote 时还应明确设置：

```text
JIANZINOTE_BUILD_FONT_READER=OFF
JIANZINOTE_BUILD_TOOLS=OFF
BUILD_TESTING=OFF
```

正式构建配置仍需满足：

- 能编译当前 C++17 代码与依赖；
- 生成的模块可由 Typst 直接加载；
- 能控制或移除 WASI/系统调用导入；
- Windows 本地开发和 CI 都可复现；
- Release 产物尺寸可接受；
- 不产生异常处理相关的 WebAssembly feature 或宿主导入。

FreeType 在 WASM 构建中关闭。需要重点验证 `nlohmann_json` 的无异常配置、标准库容器、UTF-8 处理和浮点格式化。

### 9.1 WASI stub 后处理

Emscripten 生成的原始模块在每次编译后自动交给 `wasi-stub` 处理，不要求开发者手工执行。构建流程固定为：

```text
C++ 链接
  → <build>/jianzinote.raw.wasm
  → wasi-stub --output <build>/jianzinote.wasm <build>/jianzinote.raw.wasm
  → import/ABI 检查
  → 复制或打包为 assets/jianzinote.wasm
```

CMake 通过一个依赖原始 WASM 的 custom command 生成处理后文件，并让默认构建目标依赖该输出。`wasi-stub` 返回非零状态时整个构建失败，不得继续发布未处理的模块。原始 WASM 只保留在构建目录用于诊断，不进入 Typst 包。

`WASI_STUB` 环境变量是本机便捷入口；CMake 内部使用可缓存的 `WASI_STUB_EXECUTABLE` 路径，并可通过 `find_program` 或 preset 设置它。如果配置阶段找不到可执行文件，CMake 应给出明确错误并停止，不生成会跳过后处理的构建。项目文件不写死 `D:\tools\wasi-stub`，以便 CI 和其他开发环境使用各自的安装位置。

默认调用使用 `wasi-stub` 0.3.1 的默认模块 `wasi_snapshot_preview1`。处理前应记录实际将被 stub 的函数，处理后必须再检查 import section。stub 只是为了消除 Typst 宿主不提供的导入；测试仍需要证明正常的初始化和渲染路径不依赖这些函数的真实副作用或返回值。如果存在这种依赖，应从源码或链接选项中消除，而不是用 stub 隐藏。

## 10. 测试策略

测试分为三层：

### 10.1 ABI 测试

- Typst 能成功加载 WASM；
- 参数能完整传入；
- 正常结果以 bytes 返回；
- 无效 CBOR、无效 UTF-8 和无法解析的输入能返回可读错误；
- 最终 WASM 不包含异常处理 feature，也不导入异常运行时；
- 默认构建会自动产生经 `wasi-stub` 处理的最终模块，且它不再包含 Typst 宿主无法满足的 WASI import；
- `JianziError` 能完整转换为 protocol error。

### 10.2 行为一致性测试

选取一组固定字库和自然输入，对比原生 JianziNote/SVG 输出与 WASM 输出。覆盖：

- 单个基础减字；
- 所有组合运算符；
- 括号与优先级；
- 别名和常用自然表述；
- 公式经自然输入入口的兼容行为；
- 填充区；
- Empty、Renderable、Fallback 和 Missing 四种状态；
- Fallback 分别使用默认推荐字体列表和用户自定义列表，并继承调用处的字号、基线与颜色；
- 错误输入。

### 10.3 Typst 集成测试

- 单个减字正常编译；
- 多个尺寸下比例正确；
- 行内、段落和表格中布局可接受；
- CLI 与 Web App 行为一致；
- 包内相对路径在本地包和发布包中都能解析。

性能基准至少记录字库初始化、首次渲染、重复渲染和不同减字连续渲染的耗时。

## 11. 实施阶段

### 阶段 0：设计确认

- 验证逆 glyph normalization 后的轮廓与参考字体 em 方框对齐；

### 阶段 1：技术探针

- 编译最小 C++ minimal-protocol 插件；
- 从 Typst 调用并返回固定 SVG；
- 将 JianziNote 静态链接进 WASM；
- 通过 transition 加载真实 CBOR；
- 用自然输入生成一个减字；
- 从同一基础模块分别初始化两个风格实例。

这一阶段允许使用临时命令和最少文件，目标是验证技术可行性，而不是建立完整工程。

### 阶段 2：最小可用包

- 建立正式构建脚本；
- 实现 `init(style, fallback-fonts)` 和返回的 `jianzi()` 函数；
- 增加错误处理和集成测试；
- 固定 `.wasm`、内置风格表与 CBOR 的打包方式。

### 阶段 3：API 与性能稳定

- 根据基准优化初始化和重复渲染；
- 完善尺寸和基线行为；
- 固定风格名、错误信息和兼容性策略；
- 编写发布文档和示例。

## 12. 暂定决策

- 状态处理已经确定；
- 最终 WASM 和 CBOR 暂不提交到 Git，由本地或发布/CI 流程组装；
- 待正式发布方式明确后，再重新评估制品是否入库。

## 13. 参考资料

- [Typst `plugin` 文档](https://typst.app/docs/reference/foundations/plugin/)
- [wasm-minimal-protocol](https://github.com/typst-community/wasm-minimal-protocol)
- [Emscripten C++ 异常支持](https://emscripten.org/docs/porting/exceptions.html)
- [wasmi WebAssembly 提案支持状态](https://github.com/wasmi-labs/wasmi)
