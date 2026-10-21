# Windows 编码规范 —— 可行性分析（新建 skill 前的决策材料）

> 生成于 2026-09-14 · 存放于 `.workbuddy/notes/`（`.workbuddy/` 已在 `.gitignore` 中，不会推送到 GitHub）
> 链接受访日期均为 2026-09-14；标「已核对」的是本次实际打开/检索命中的页面，其余为权威入口。

## 修订记录

### R2 · 2026-09-14 复核

用户第二次提出同样三个问题时做的独立复核。**结论方向不变，但有 1 处写反、2 处过时**，均已就地更正：

| # | 位置 | 原文 | 更正 |
|---|---|---|---|
| 1 | §2.2 | 「按**规则 ID** 设的 severity 构建时不生效（须用 rule-ID 语法）」—— 自相矛盾 | 方向写反了。**选项式**语法（`option = value:severity`）只在 IDE 生效、**构建时不被 C#/VB 编译器识别**；要在构建期强制，**必须**改写成**规则 ID 式** `dotnet_diagnostic.IDE0040.severity = warning`。另：.NET 9 起选项式也能在构建期生效 |
| 2 | §1.3 / §2.1 | PowerShell「**无格式器**，只能靠 EditorConfig + 人工」 | **过时且是错的**。PSScriptAnalyzer 内置 `Invoke-Formatter` 与四个格式预设（`CodeFormatting` / `CodeFormattingOTBS` / `CodeFormattingAllman` / `CodeFormattingStroustrup`），规则含 `PSPlaceOpenBrace` / `PSPlaceCloseBrace` / `PSUseConsistentWhitespace` / `PSUseConsistentIndentation` / `PSAlignAssignmentStatement` / `PSAvoidTrailingWhitespace`。PowerShell 侧**三件套齐全**，只是格式器不独立成 CLI。原先「PowerShell 侧最缺格式器」的结论作废 |
| 3 | §1.1 | StyleCop.Analyzers「Roslyn 化，仍在广泛使用」 | 成立但不完整。**至今没有 1.2.0 正式版**：NuGet 最新为 `1.2.0-beta.556`（2023-12-21）；仓库仍在动（最后一提交 2025-12-31）。⚠️ 网上「StyleCop 已归档 / 已并入 `Microsoft.CodeAnalysis.NetAnalyzers`」的说法**与官方仓库和 NuGet 实况不符**，不可采信 —— 采信就会漏掉「成员间空行」这条唯一检测源 |

新增四条事实（原文没有）：

1. **命令行构建默认关闭 code-style（IDExxxx）分析** —— 只写 `.editorconfig`、不设 `EnforceCodeStyleInBuild=true`，CI 会**一片绿**。与本侧既有教训同构（`.swiftlint.yml` 的 `included` 指向不存在目录 → 一条都不扫却报 0 违规），属「假基线」。
2. **部分 IDE 规则是 `EnforceOnBuild.Never`**（`SimplifyNames`、`RemoveUnqualification`、`PreferBuiltInOrFrameworkType` 等，出于性能考虑只在 IDE 里跑）—— 即使开了 `EnforceCodeStyleInBuild` 也压不住，须进「已知查不出」清单。
3. **驱动认证只要求「跑过」，不要求「全过」**：Static Tools Logo Test 只查 DVL 是否存在（证明跑过 CodeQL），**不要求所有规则通过**。所以「WHCP 强制 CodeQL」是**流程强制**，不是零违规强制。
4. **C++ Core Guidelines 自己声明不管命名与缩进**（原文 *less concerned with low-level issues, such as naming conventions and indentation style*）—— C++ 侧的命名/格式必须另找来源。且 clang-tidy 的 `cppcoreguidelines-*` 仅覆盖其中一小部分（第三方统计约 30 条检查、8 条可自动修），**大多数条目没有检查器**。这是「约束力 ≈ 可检查性」在 C++ 侧最硬的证据。

---

## 0. 先纠正一个前提：不存在一份「Windows 官方编码规范」

这是整个分析里最重要的一条。Swift 侧能写出这份 skill，是因为存在 **S1（Swift API Design Guidelines）+ swift-format** 这条清晰的官方权威链。Windows 侧没有等价物 —— **Windows 是平台，不是语言**。它不定义编码规范；规范分散在四个互相独立的层里：

| 层 | 谁定 | 有没有权威文本 | 有没有工具 |
|---|---|---|---|
| 语言与运行时 | C#/.NET、C++（ISO C++ 基金会 + 微软规则集）、PowerShell | 有，而且不止一份（见 §1） | 有，而且不止一套（见 §2） |
| 领域合规 | 微软 WHCP 认证（驱动）、MISRA/CERT（安全关键） | 有，且是**认证硬要求**而非建议 | 有，且是准入闸门（CodeQL + DVL） |
| 平台与界面 | 微软设计团队 / Windows App SDK | 有（Fluent Design、WinUI 指南） | 弱，主要是设计评审 |
| 跨语言底座 | EditorConfig、提交与 CI 惯例 | 事实标准 | 有 |

**这个差异决定了新 skill 的设计目标必须换。** Swift 侧的病是「官方没有单一格式标准 + 生态工具只有两个」→ 所以我们做的是**补缺口**（成员空行那条规则就是被这个病逼出来的）。Windows 侧的病恰好相反：**标准太多、工具太多、规则上千条** → 真正的病是「选不出来、规则噪音大、存量工程无法一次全开、配置静默不生效」。

所以新 skill 的价值点不是「补充规范」，而是 **收敛选择 + 分级 + 可验证的基线迁移**。

---

## 1. 第 1 问：市面上常用的规范文档与官方文档有哪些

### 1.1 C# / .NET（Windows 应用开发主力，最可能的目标栈）

**第一方（微软官方）**

| 文档 | 定位 | 权威度 |
|---|---|---|
| 《Framework Design Guidelines》（Cwalina / Abrams 等） | .NET 库设计的权威书；命名与 API 设计的事实标准 | **最高**（是书，受版权保护，不可整篇快照） |
| Learn：.NET 库设计指南 | 上书的在线化 | 高 |
| Learn：常见 C# 代码约定（已核对） | 微软 dotnet/docs 自己的规范；**页面明确写着「是常见约定的示例，不是权威列表，权威见框架设计准则」** | 高，但自认非权威 |
| Learn：代码样式规则 IDExxxx（已核对） | 语言规则 / 格式规则 / 命名规则三类的索引 | 权威索引 |
| Learn：质量规则 CAxxxx | 正确性、安全性、性能、可靠性、可维护性 | 权威索引 |
| dotnet/runtime 的 `docs/coding-guidelines/coding-style.md` + 仓库 `.editorconfig` | **运行时团队自己的规范** | 实际上是最有参考价值的「大厂内部规范」样本 |
| dotnet/roslyn 的 `eng/config/globalconfigs/{Common,Shipping,NonShipping}.globalconfig`（已核对） | 编译器团队把规则按三档配置 | 同上；直接可抄的分档思路 |

**行业权威**

- Google C# Style Guide（存在但维护不活跃）
- StyleCop（经典）→ **StyleCop.Analyzers**（Roslyn 化）。它的不可替代性在于：**「成员之间必须有分隔空行」（`SA1516`）与成员顺序（`SA1201`）这类规则，Swift 侧只能自写脚本（`verify_member_spacing.sh`）、C# 侧无内置 analyzer，只有它**。现状（R2 已核对）：NuGet 最新 `1.2.0-beta.556`（2023-12-21），**长期停留在 beta、无正式版**；仓库仍活跃（最后一提交 2025-12-31）。误信「已归档」会直接丢掉这条唯一检测源
- 第三方 analyzer 生态：NuGet 上官方的 + 第三方「Analyzer」包超过 2000 个（这条既是资源也是噪音源）

### 1.2 C++（Win32 / 原生 / 驱动上层）

**第一方**

| 文档 | 定位 |
|---|---|
| **C++ Core Guidelines**（Stroustrup / Sutter，标准 C++ 基金会维护） | 事实上的官方权威，约 500 条规则，**开源可快照** |
| Learn：使用 C++ Core Guidelines 检查工具（已核对） | VS 内置 Core Check 子集，随 VS2017+ 默认安装 |
| Learn：C++ 代码分析规则 C6xxx + Microsoft Native Recommended Rules | MSVC 侧的规则集 |
| Learn：SAL 2 注解 | 驱动与安全关键代码的契约注解（Code Analysis 的核心机制） |
| Office C++ Guidelines（microsoft.github.io/OfficeCppGuidelines） | 微软 Office 团队公开的 C++ 规范，罕见的「内部规范外传」样本 |
| MSVC 编译选项：`/W4` `/WX` `/permissive-` | 事实上的第一条闸门 |

> **C++ Core Guidelines 的自我边界（R2 已核对，很重要）**：文档原文写着它 *less concerned with low-level issues, such as naming conventions and indentation style* —— 即**它不管命名与缩进**，那部分必须另找来源（Google / LLVM / 项目自定）。再者，clang-tidy 的 `cppcoreguidelines-*` 检查只覆盖其中一小部分（第三方统计约 30 条、其中 8 条可自动修），**多数条目没有检查器**。两条合起来的后果：C++ 侧「够格标 MUST 的条目」远少于 C# 侧，规范里大量条目只能是 SHOULD + 人工评审。

**行业权威**

- Google C++ Style Guide（最常被借用，含 clang-format 配置思路）
- LLVM / Mozilla / WebKit / Qt 风格
- **MISRA C/C++、AUTOSAR C++14**（安全关键，汽车/医疗）
- SEI CERT C/C++ 编码标准（安全）

### 1.3 PowerShell / 脚本与自动化（Windows 运维必配）

| 文档 | 定位 |
|---|---|
| **PSScriptAnalyzer 规则与建议**（已核对） | 微软官方，按 Cmdlet Design / Script Functions / Script Style / Script Security / DSC 分组，每条标 Severity；**其中相当一部分是「TBD 无规则」的建议** |
| **`Invoke-Formatter` + 四个 `CodeFormatting*` 预设**（R2 新增，已核对） | **格式权威**。内置格式化引擎（按 `PlaceOpenBrace → PlaceCloseBrace → UseConsistentWhitespace → UseConsistentIndentation → AvoidTrailingWhitespace` 固定顺序执行），并提供 Stroustrup / OTBS / Allman 三套花括号风格预设。`Invoke-ScriptAnalyzer -Fix` 走同一套建议修正 |
| `PSScriptAnalyzerSettings.psd1` | 配置载体。**放在仓库根即被自动发现**（VS Code 的 PowerShell 扩展默认也读这个文件名），编辑器告警与 CI 判据天然同源 |
| Approved Verbs（`Get-Verb` 批准动词表） | 命令命名的事实标准 |
| about_Comment_Based_Help | 注释帮助规范（`ProvideCommentHelp` 规则依赖它） |
| DSC 资源编写规范 | 配置管理侧 |
| PowerShell Practice and Style（PoshCode，社区） | 社区事实权威 |

### 1.4 平台与界面（如果目标不只是「代码文件」，而是「Windows 应用」）

- Fluent Design / Windows 11 设计原则、WinUI 3 / Windows App SDK 指南
- MSIX 打包与清单规范（微软当前的推荐分发形态）
- 可访问性（Accessibility Insights）、高 DPI、深色模式 / 主题资源
- WinRT API 的 .NET 投影命名规则、本地化与资源命名

### 1.5 驱动与内核（若涉及）

- WDK 文档 + **CodeQL**（已核对：三家静态分析工具里，**Static Driver Verifier 已退役**——24H2 RTM WDK 中不再提供；**Code Analysis for drivers 在 24H2 仍可用但已宣布将退役**；CodeQL 成为主要静态分析工具）
- WHCP 的 Static Tools Logo Test **强制要求 CodeQL**，产出 DVL（Driver Verification Log）才能过认证。**但要求的是「跑过」而不是「零违规」**（R2 已核对）：STL 只查 DVL 文件是否存在，**不要求所有规则通过**。所以这条是**流程强制**，别把它写成「必须零告警」
- SAL 2 注解、内核栈用量限制（C6262 默认 1KB，**内核总栈仅 12KB**）
- 结论：这一层是**认证准入**，不是可选项 —— 规则本身就带法律/商业后果。

---

## 2. 第 2 问：Windows 侧的标准有哪些？swift-format / SwiftLint 的对应物是什么

### 2.1 一张对照表

| 能力 | Swift | C# / .NET | C++ (MSVC / clang) | PowerShell |
|---|---|---|---|---|
| 格式器 | `swift format` | **`dotnet format`**（随 .NET 6+ SDK 内置） | `clang-format` | **`Invoke-Formatter`**（PSScriptAnalyzer 内置，非独立 CLI — R2 更正） |
| Linter / 分析器 | `SwiftLint` | **Roslyn analyzers**（CAxxxx + IDExxxx）+ StyleCop.Analyzers + 第三方 | `clang-tidy` + MSVC `/analyze`（C6xxx）+ cppcheck | **PSScriptAnalyzer** |
| 配置载体 | `.swift-format` + `.swiftlint.yml` | **`.editorconfig`**（+ `.globalconfig` / MSBuild 属性） | `.clang-format` + `.clang-tidy` + `.editorconfig` | `PSScriptAnalyzerSettings.psd1` |
| 只读检查 | `swift format lint` | `dotnet format --verify-no-changes` / `-warnaserror` | `clang-format --dry-run -Werror` / `/WX` | `Invoke-ScriptAnalyzer` 退出码 |
| 自动修复 | `--in-place` | `dotnet format` | `clang-format -i`、`clang-tidy --fix` | `Invoke-ScriptAnalyzer -Fix` |
| 构建立即生效 | 无（靠钩子） | **有**：`EnforceCodeStyleInBuild` + `TreatWarningsAsErrors` | 有（`/WX`） | 无 |
| 命名可机器化 | 弱（只有 SwiftLint 的 `identifier_name` + 人评审） | **强**：`.editorconfig` 声明式命名规则（前缀/大小写/可见性维度） | 中：`readability-identifier-naming` CheckOptions | 弱 |
| 认证级闸门 | 无 | 安全规则 CA5xxx | **驱动需 CodeQL + DVL** | 安全规则（明文密码等） |

**三条最重要的结论：**

1. **`dotnet format` ≈ `swift format`，`.editorconfig` ≈ `.swift-format`**，同样是单一配置载体；**Roslyn analyzers ≈ SwiftLint**，但能力强得多（命名、设计、安全、性能全覆盖）。
2. **.NET 侧有一个 Swift 侧没有的能力：构建立即生效**（`EnforceCodeStyleInBuild=true` + `TreatWarningsAsErrors=true`）。这意味着「跑不过就提交不了」不依赖钩子，可以直接压在编译上 —— 比 Swift 侧更硬。**但前提是显式打开**：code-style（IDExxxx）分析在**命令行构建下默认禁用**，漏设这个属性 CI 会全绿而毫无意义（见 §2.2）。
3. **C++ 侧最弱，PowerShell 侧其实齐备**。如果目标含 C++，「格式化 + 命名」尚可机器化，但**设计约束大半只能人工评审**（Core Guidelines 自称不管命名与缩进，且多数条目无检查器）。PowerShell 侧**三件套齐全**（`Invoke-Formatter` + `Invoke-ScriptAnalyzer` + `PSScriptAnalyzerSettings.psd1`），原先记作「连格式器都没有」是**错的**（R2 已更正）。

### 2.2 一个必须写进规范的坑清单（和我们在 Swift 侧踩过的坑同构）

| 坑 | Windows 侧的表现 | 对应 Swift 侧的教训 |
|---|---|---|
| **配置静默不生效** | `.editorconfig` 不在 `root=true` 的层级链上就不生效；**选项式** severity（`option = value:severity`）在 .NET 8 及更早**构建时不被编译器识别**，须改写成**规则 ID 式** `dotnet_diagnostic.<ID>.severity`（.NET 9 起选项式也可） | `.swiftlint.yml` 的 `included` 指向不存在的目录 → 一条都不扫、报 0 违规 |
| **命令行构建默认关掉样式分析**（R2 新增，最容易踩） | code-style（IDExxxx）分析在**命令行构建下默认禁用**。不设 `EnforceCodeStyleInBuild=true`，`dotnet build` 与 CI 全绿**证明不了任何事** | 无 `.swiftlint.yml` 时 `force_unwrapping` 不生效，同一段代码报 0 条 |
| **opt-in 规则默认不开 / 有些规则永远查不出**（R2 扩充） | `AnalysisLevel` / `EnableNETAnalyzers` 决定启用面；另有 `EnforceOnBuild.Never` 的规则（`SimplifyNames`、`RemoveUnqualification`、`PreferBuiltInOrFrameworkType` 等）出于性能考虑**只在 IDE 里跑**，开了开关也压不住 | `.swiftlint.yml` 的 `included` 指向不存在的目录 → 一条都不扫、报 0 违规 |
| **两套闸门重叠报同一问题** | StyleCop 的 SA1xxx（格式）与 `IDE0055`（格式）重叠；CAxxxx 与 SAxxxx 亦有交叠 | 我们在 Swift 侧**显式禁用了 SwiftLint 的全部格式规则**来避免双报 —— C# 侧要做同样的取舍 |
| **「跑过脚本」≠ 达标** | `dotnet format` 只修可自动修的；不少 IDExxxx 不提供 fix | Swift 侧：只跑 `swift format` 不碰命名/文档/魔法值，必须明确告知还剩什么 |
| **只看退出码** | CI 里 `dotnet format` 的成功不代表合规（需 `--verify-no-changes`） | 补丁被沙箱静默拦下、`git apply` 静默跳过却返回 0 |

---

## 3. 第 3 问：按 Swift 的架构，有哪几种方案

### 3.0 先复述「Swift 架构」到底是哪几条设计原则

这套 skill 的价值不在文件多，而在四条原则（`SKILL.md` + 21 个文件只是它们的产物）：

1. **薄入口**：`SKILL.md` 只放路由与最高频规则，细节推到 `references/` 按需加载（description 是每会话常驻成本）。
2. **单一权威**：同一事实绝不写两份；`verify_consistency.sh` 专门抓副本漂移。
3. **约束力 ≈ 可检查性**：能机器查的绝不靠「写个 MUST」；查不出的必须降级为 SHOULD。
4. **引文可核 + 离线自足**：内置权威来源快照，`verify_citations.sh` 逐字校验，集成后零网络依赖。

### 3.1 方案 A：单栈单 skill（C#/.NET 版）—— 推荐起点

结构逐文件照搬，只替换内容与工具：

| Swift skill 资产 | C#/.NET 版对应物 | 复用度 |
|---|---|---|
| `SKILL.md` 薄入口 | 同（触发词换成 dotnet format / StyleCop / Roslyn analyzer / .editorconfig / C# 命名） | 骨架 100% |
| `references/swift-coding-standards.md` | `csharp-coding-standards.md`（0 问题定义 / 1 权威依据 / 2 强制等级 / 3 命名 / 4 格式 / 5 语言与设计 / 6 测试 / 7 工具链 / 8 迁移） | 章节骨架 100% |
| `references/comment-standards.md` | XML 文档注释规范（`<summary>/<param>/<returns>/<exception>`）+ `CS1591` + `GenerateDocumentationFile` | 结构 100%，**C# 侧更成熟：可构建强制** |
| `references/defect-catalog.md` | 缺陷目录（CAxxxx / IDExxxx / SAxxxx 分档：机器可检出 / 可 grep / 人工） | 骨架 100%，机器可检出的比例更高 |
| `references/naming-antipatterns.md` | 命名反模式 + 可接受词表（**须重新建立中文语境词表**：如 `svc`/`mgr`/`cfg`/`tmp` 是否可接受） | 判据 100%，词表需重建 |
| `references/remediation-playbook.md` | 整改手册（9 条验收换成 .NET 版：`--verify-no-changes` 无输出 + 构建 0 warning + 文档注释齐 + 命名评审） | 逻辑 100% |
| `references/official/*.md` | 快照集须重选（**版权差异，见 3.5**） | 机制 100%，内容 0% |
| `assets/swift-format.json` | `assets/editorconfig` 模板（+ 可选 `.globalconfig`） | 机制 100% |
| `assets/swiftlint.yml` | `assets/analyzer-packages` + `Directory.Build.props` 片段 + `stylecop.json` | 机制 100% |
| `scripts/bootstrap_swift_style.sh` | `bootstrap_dotnet_style.sh`（检测 SDK/dotnet format、生成配置、采基线） | 心智模型 100% |
| `scripts/remediate.sh` | `remediate.sh --check/--fix`（`--verify-no-changes` 天然对应只读） | 结构 100% |
| `scripts/verify_consistency.sh` | 同（期望值从 assets 模板与文档表格推导） | **复用度最高** |
| `scripts/verify_citations.sh` | 同（快照集换成可分发来源） | 机制 100% |
| `scripts/verify_member_spacing.sh` | 大概率**不需要**（.NET 侧 StyleCop 覆盖了成员顺序/文件头类检查） | — |

- 成本：最低（一个栈、一套工具链、一条验证链）。
- 收益：可直接用于真实工程，能立刻产出「N 处违规 / M 个文件」这样的数字。
- 风险：只覆盖一个栈；若目标工程是 C++ 混合栈则不适用。

### 3.2 方案 B：伞形 Windows skill（一个入口，多栈分支）

`SKILL.md` 按栈路由到 `references/csharp/`、`references/cpp/`、`references/powershell/`。

- 收益：一个入口覆盖「Windows 平台」这个用户心智；触发一次就够。
- 成本（真问题）：
  - description 是常驻成本，要同时容纳三栈触发词 → 会明显变胖；
  - 三栈的闸门数量不同（C# 有构建立即生效、C++ 有认证级 CodeQL、PS 无格式器），**「四道闸门」这类结构无法统一表述**；
  - `verify_consistency.sh` 的目标从「两套配置五个阈值」变成 N×M 矩阵，维护成本陡增。
- **结论：不要在第一步就做。** 我们 Swift 侧已经因为「同一事实写了两份」踩过漂移（`drain` 事件）；多栈会让这个问题指数化。

### 3.3 方案 C：元框架（把骨架抽成生成器 / 模板）

不写「Windows 规范」，而写「**规范 skill 生成器**」：输入语言、工具链、权威来源清单，产出 skill 目录树。

- 收益：可覆盖任意语言（C#、C++、Rust、Go、Python…）；把这一周踩过的坑固化成模板约束（单一权威、可检查性、配置联动、引文校验）。
- 成本：抽象层次高，**必须先有第二份实例才不空转**；对「我就要一份 Windows 规范」是过度设计。
- **结论：作为 B 之后的第二步**（先用 A 或 B 做出第二份实例，再反推抽象），不要一开始做。

### 3.4 方案 D：扩展现有 skill 为「跨语言编码规范」—— 明确不推荐

把 `swift-coding-standards` 改名为 `coding-standards`，内部按语言分目录。

为什么不推荐：

1. **直接违反自己的「薄入口」原则** —— description 要同时覆盖 Swift 与 Windows，常驻成本与误触发都会变差；
2. 违反单一职责，且现有 21 个文件、两套自检都是围绕 Swift 生态建的（尤其 `verify_member_spacing.sh` 是 Swift 生态空白逼出来的产物），混入新栈会让 `verify_consistency.sh` 的「单一权威来源」假设失效；
3. 已经推送到 GitHub 的仓库名就是 `swift-coding-standards`，改名会造成既有工程引用断链。

### 3.5 一个容易被忽略的真问题：**快照的版权边界**

Swift 侧敢内置 S1–S6 快照，是因为这些来源可分发。Windows 侧**不能照抄这个做法**：

| 来源 | 可否内置快照 | 处理方式 |
|---|---|---|
| C++ Core Guidelines（isocpp/ GitHub） | 需逐个确认其仓库许可（分代码/文档） | 可快照则快照，否则引文 + 链接 |
| Microsoft Learn 各页 | 页脚通常标 CC BY 4.0（文档）/ MIT（代码），**须逐页核实** | 建议**引文 + 链接 + 校验清单**，不整篇复制 |
| 《Framework Design Guidelines》 | **书，不可快照** | 只做条目索引 + 引文，明确指向原书 |
| dotnet/runtime、dotnet/roslyn 的配置与规范文件 | 开源仓库（MIT） | 可快照 |

**这意味着 `verify_citations.sh` 的可用范围会变窄** —— 它依赖「有快照可比对」。若合法快照源不足，就得改设计：把「逐字校验」降级为「引用条目存在性校验 + 链接可达性检查」。这一条必须在设计阶段就决定，不能事后补。

### 3.6 推荐路径

```
A（单栈 C#/.NET）→ 在 1–2 个真实工程上验证并拿到数字 →（若确实需要多栈）B →（若确实要复用到其他语言）C
```

理由：与 Swift skill 的演化史一致 —— 先在一个真实工程（UGDockNative）上把规则打成数字，再抽象。A 的成本最低，且除 `verify_member_spacing.sh` 外几乎所有脚本都可直接改造。

### 3.7 必须移植的五条 Swift 侧经验

1. **约束力 ≈ 可检查性**：每条 MUST 先找检测器；找不到就降级 SHOULD。.NET 侧可检查性更高，但 C++ 侧设计约束大半要降级 —— 这件事必须写进规范，不能假装都能查。
2. **单一权威**：阈值与词表只写一份。.NET 侧天然是 `.editorconfig`，别再散落回文档。
3. **配置联动必须显式列出**：Swift 侧是「五者必须一致」（`.swift-format` 的四个值 + `.swiftlint.yml` 的一处）。.NET 侧对应：`.editorconfig` 的 `indent_size` / `end_of_line` / 各 `dotnet_diagnostic.*.severity` 与 `Directory.Build.props` 的 `AnalysisLevel` / `EnforceCodeStyleInBuild` / `TreatWarningsAsErrors` 必须一致。C++ 侧：`.clang-format` 的 `ColumnLimit`/`IndentWidth`、`.clang-tidy` 的 `readability-identifier-naming` 选项、CI 的 `-Werror` 三处必须一致。
4. **工具分工必须清晰、禁止重叠**：Swift 侧显式禁用了 SwiftLint 的全部格式规则。C# 侧对应取舍：StyleCop 的 SA1xxx 与 `IDE0055` 二选一，否则同一问题报两遍、噪音翻倍。
5. **「跑过脚本 ≠ 达标」，且只核验副作用不核验退出码**。`.NET` 侧 `dotnet format` 尤其容易给人「已经合规」的错觉。

---

## 附：主要来源入口

- `dotnet format`：https://learn.microsoft.com/dotnet/core/tools/dotnet-format （已核对）
- .NET 代码样式规则索引（IDExxxx）：https://learn.microsoft.com/dotnet/fundamentals/code-analysis/style-rules/ （已核对）
- 代码分析配置文件（EditorConfig / globalconfig）：https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-files （已核对）
- .NET 代码分析总览 —— **`EnforceCodeStyleInBuild` 与 `EnforceOnBuild.Never` 的权威出处**：https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview （R2 已核对）
- .NET 代码样式规则选项 —— **选项式 vs 规则 ID 式 severity 的区别**：https://learn.microsoft.com/dotnet/fundamentals/code-analysis/code-style-rule-options （R2 已核对）
- 常见 C# 代码约定：https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions （已核对）
- .NET 质量规则 CAxxxx：https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/
- .NET 库设计指南：https://learn.microsoft.com/dotnet/standard/design-guidelines/
- StyleCop.Analyzers：https://github.com/DotNetAnalyzers/StyleCopAnalyzers
- C++ Core Guidelines：https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines
- VS 使用 Core Guidelines 检查工具：https://learn.microsoft.com/cpp/code-quality/using-the-cpp-core-guidelines-checkers （已核对）
- clang-format / clang-tidy：https://clang.llvm.org/docs/ClangFormat.html · https://clang.llvm.org/extra/clang-tidy/
- 驱动代码分析（将退役）：https://learn.microsoft.com/windows-hardware/drivers/devtest/how-to-run-code-analysis-for-drivers （已核对）
- CodeQL 与驱动认证：https://learn.microsoft.com/windows-hardware/drivers/devtest/static-tools-and-codeql （已核对）
- PSScriptAnalyzer 规则与建议：https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules-recommendations （已核对）
- PSScriptAnalyzer 仓库：https://github.com/PowerShell/PSScriptAnalyzer
- PSScriptAnalyzer 用法 —— `Invoke-Formatter` / Settings / 内置预设：https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer （R2 已核对）
- SDV 退役与 CodeQL 转正的官方公告：https://learn.microsoft.com/answers/questions/1691689/sdv-deprecation-announcement （R2 已核对）
- Static Tools Logo Test —— 只查 DVL 是否存在，不要求规则全过：https://learn.microsoft.com/windows-hardware/test/hlk/testref/6ab6df93-423c-4af6-ad48-8ea1049155ae （R2 已核对）
- Approved Verbs：https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands
- Google C++ / C# Style Guide：https://google.github.io/styleguide/cppguide.html · https://google.github.io/styleguide/csharp-style.html
- Office C++ Guidelines：https://microsoft.github.io/OfficeCppGuidelines/
- Windows 设计 / WinUI 3：https://learn.microsoft.com/windows/apps/design/ · https://learn.microsoft.com/windows/apps/winui/winui3/
- EditorConfig：https://editorconfig.org/
