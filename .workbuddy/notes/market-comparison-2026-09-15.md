# 与市面主流方案的比对

> 建立于 2026-09-15。**未改动任何发布内容**，属分析文档（留在 `.workbuddy/`，不进 git）。
> 比对对象：本仓库 `swift-coding-standards` v1.5.6（21 个内容文件）vs 市面主流方案。
> 所有「市面方案」的事实均来自当日检索，链接见第 6 节；所有「本规范」的事实均来自本地实测。

---

## 0. 结论摘要

三句话：

1. **差异不在规则条数，在另外三个维度** —— 覆盖到「机器查不出」的层、可核验性（离线快照 + 逐字引文校验）、以及「人工排版同等有效」这条**与全行业相反的立场**。规则数量上我们并不比 Google / Airbnb 多。
2. **真正落后的是两件事**：**测试框架的代际**（Swift Testing 已是官方推荐，WWDC 2026 的主题就是迁移，我们零处提及）与 **AI 专属缺陷**（视图层碎片、性能陷阱、拆分粒度 —— 市面已有零散尝试，我们全缺）。
3. **有一条结构性隐患值得重视**：我们的体量上限比市面主流**严得多**（函数 60 行 vs 市面 160），但**下限完全缺失**。上严下无 —— 规则本身只朝「更碎」一个方向施压。这与第 4 轮提的粒度问题同源。

---

## 1. 市面方案的地形（四层，各层做的事完全不同）

比对容易失焦，是因为「市面方案」不是一个东西，而是四层：

### 第 1 层：官方规范（唯一权威）
- **Swift API Design Guidelines**（`swift.org/documentation/api-design-guidelines`）—— 命名、参数标签、文档注释的**唯一官方权威**。纯文档，无工具、无配置文件、无版本号。核心是 *Clarity at the point of use*。
- **The Swift Programming Language** —— 语言语义，不是规范。

> 关键事实：**Swift 官方没有格式规范**。官方给的是**格式化器**（swift-format），不是格式标准。本规范 1.1 节已写清这一点，市面多数指南反而含糊。

### 第 2 层：行业风格指南（文档，互相抄）
| 指南 | 定位 | 工具化程度 |
| --- | --- | --- |
| **Google Swift Style Guide** | S1/S3 未覆盖处的格式补充 | 无 |
| **LinkedIn Swift Style Guide** | 数据建模 / 可选值 / guard / 注释 | 无（2024-12 起对齐 swift-format 默认） |
| **Airbnb Swift Style Guide** | 最强的一家：有 guiding tenets、有 SPM 插件 **和官方 AI skill** | **高** |
| **Kodeco（原 raywenderlich）** | 教程向，写给学习者 | 无 |

**Airbnb 是市面唯一把「原则 → 规则 → 工具 → agent」打通的**：它的 guiding tenets 明确写了三条 —— 纯语法规则**必须可自动修复**、lint 只用于影响运行时的规则、**不能自动化的最佳实践「仍然欢迎，作为给人**和 AI agent**的建议」**。最后半句是它和我们思路最接近的地方。它还有 `swift package format` 命令插件（一条命令 format 或 lint 整个包，lint 模式返回非零退出码）。

### 第 3 层：工具（这里只有两个事实标准 + 一个易混淆项）
- **SwiftLint** —— 语义/inlint 的事实标准，无有力竞品（本机实测 `0.63.2`）。
- **Apple `swift-format`** —— Apple 官方格式化器，随 Swift 6.x 工具链自带（本机 Swift `6.4`，`swift format --version` 输出为 `main`，即它不按语义化版本发布）。
- **nicklockwood `SwiftFormat`** —— **社区**格式化器，与上面那个**同名但完全是另一个东西**。规则更丰富、可定制性更强、社区成熟度高，Cursor/CI 集成更成熟，但**非官方**。本机未安装。

> 这一层最容易被搞混：`swift-format`（Apple，连字符）与 `SwiftFormat`（nicklockwood，驼峰）是两个工具。市面文章经常混用，本规范刻意只用前者并显式说明理由。

### 第 4 层：Agent 形态（2026 年的新战场，也是与我们最同质的一层）
| 产物 | 性质 | 做什么 |
| --- | --- | --- |
| **Airbnb 官方 AI skill** | 官方 | 「总结风格指南中**不可自动修复**的最佳实践」 |
| `airbnb-swift-style-agent-skill` | 第三方 | 把 Airbnb 指南转成 skill，做 review + 改写，规则放 `references/rules.md` |
| `swift-code-reviewer-skill`（npm） | 第三方 | 七阶段 review：规格符合性 / Swift 质量 / **SwiftUI 模式** / **性能** / 安全 / 架构 / 项目规范，外加 **agent loop feedback** |
| `Swift API Design Guidelines Skill`（LobeHub） | 第三方 | 把官方指南切成 8 个 reference 文件让 agent 读 |
| CLAUDE.md / AGENTS.md 模板 | 社区惯例 | 项目级约束，含 lint/format 命令与「硬规则」清单 |
| `faion-code-quality`（skillmd.ai） | 第三方 | 含 **Code Decomposition Principles**：When to Split / When NOT to Split 清单 |

**这一层的结论**：agent 形态已经不稀奇了 —— 连 Airbnb 官方都在发。**真正稀缺的是「有验证机制」的 agent 规范**（见第 3 节差异 3、4）。

---

## 2. 逐维度比对矩阵

| 维度 | 官方（S1/S3） | 行业指南（Google/LinkedIn/Airbnb） | 工具层 | Agent 形态 | **本规范** |
| --- | --- | --- | --- | --- | --- |
| 命名 | ✅ 唯一权威 | 引用 S1 + 本地细则 | SwiftLint 部分可查 | 摘要 | **100% 采用 S1**，另加可判定判据 |
| 格式 | 只有格式化器 | 各自一套（2/4 空格分歧） | swift-format / SwiftFormat | 摘要 | swift-format 默认 + 配置固化 |
| 语义/设计约束 | 仅命名与文档 | 少量 | SwiftLint 部分 | review 清单 | **17 类缺陷，含 6 类双方都查不出** |
| 视图层（SwiftUI） | ✗ | ✗ | ✗ | ✅ 有（CLAUDE.md 类） | **✗ 缺口** |
| 性能陷阱 | ✗ | ✗ | ✗ | ✅ 有 | **✗ 缺口** |
| 测试规范 | ✗ | 少 | 部分规则 | 摘要 | 有第 6 章，但**基于 XCTest，未及 Swift Testing** |
| 拆分粒度（下限） | ✗ | ✗ | ✗（只有上限） | 零散（faion / 博客） | 有提案**未合入** |
| 整改流程 | ✗ | ✗ | 只有 lint | review 报告 | **9 条验收的整改手册 + 管线脚本** |
| 引文可核验 | ✗ | ✗ | ✗ | ✗ | **✅ 离线快照 + 逐字校验（唯一）** |
| 内部一致性自检 | ✗ | ✗ | ✗ | ✗ | **✅ 防副本漂移（唯一）** |
| 强制等级定义 | ✗ | 部分（MUST/SHOULD） | 阈值 | 硬规则清单 | MUST/SHOULD/MAY + 检查手段 + 后果 |
| 迁移策略 | ✗ | ✗ | ✗ | ✗ | **五批分批 + 提交纪律** |
| 机器可读规则导出 | ✗ | ✗ | 配置即规则 | ✅（rules.md） | **✗ 缺口**（规则在 724 行正文里） |
| 版本化 / 变更记录 | ✗ | 部分 | 工具版本 | ✗ | ✅ 12 条变更记录 |

---

## 3. 六个真实差异（我们独有，或被我们反向处理）

### 差异 1：覆盖到「机器查不出」的那一层
市面指南的边界大致是「格式 + 命名 + 少量语言用法」。我们的 17 类里有 6 类**市面基本不碰**：
魔法字符串、数值参数缺单位、数据打包失当（元组 ≤2 / 关联值具名）、并发逃逸未说明、测试断言过弱、成员间缺分隔空行。

其中**成员间缺分隔空行**最特殊：swift-format 与 SwiftLint **都没有这条规则**，所以我们为它单独写了 `scripts/verify_member_spacing.sh`。市面所有方案在这一条上都是空白。

### 差异 2：「人工排版与工具排版同等有效」—— 这条与全行业相反
- Google / LinkedIn / Airbnb / Kodeco / 所有 CLAUDE.md 模板：**格式化器是唯一排版权威**，跑 `--in-place` 是天经地义的。
- 我们：**两个合法来源**，`--in-place` 不是提交前必做动作，钩子与 CI **只 lint、禁止自动改写源码**。

这条不是疏忽，是刻意的（`respectsExistingLineBreaks` 不得关闭、局部豁免用 `// swift-format-ignore`）。**代价**是我们必须自己定义「哪些格式项是硬规则」——于是有了那个只有 5 项的清单。**收益**是 AI 批量重排不会覆盖人的排版意图。

> 值得注意：Airbnb 的 tenets 说「纯语法规则**必须**可自动修复」，我们是唯一在这一点上明确保留人工排版合法性的。这可能是我们最大的分歧点，也可能是最该坚持的一条 —— 但它需要一句更强的理由，否则读起来像「懒得跑格式化」。

### 差异 3：引文可核验（离线快照 + 逐字校验）—— 全行业唯一
`references/official/` 内置 S1–S6 原文快照，`verify_citations.sh` 校验正文中标注为原文的句子与快照**逐字一致**，并提供反向启发扫描（正文斜体英文句必须有出处）。

**这不是多余机制**：`SOURCES.md` 自证了它的价值 —— S4 原先指向的官方 `docs/Style.md` 已被从所有分支与标签移除（实测 404），内容并入了另一个文件。任何「只放链接」的指南此时都会静默失去依据。

市面所有方案都是「引用链接，烂了就烂了」。

### 差异 4：内部一致性自检（防副本漂移）—— 全行业唯一
`verify_consistency.sh` 专抓「同一事实写了两份」：验收条数、版本号、缩进/行长五处联动、frontmatter 限额。**期望值一律从单一权威来源推导**，不在脚本里写第二份硬编码。

设立它的理由是本工程真实吃过亏（`drain` 在词典与整改手册间漂移）。市面指南不设这种机制，因为它们通常只有一个文件。

### 差异 5：判据优先于清单
- 我们的命名判据只有一条：**遮住定义只看调用点，陌生人能否说出这行在做什么。**
- 市面（Airbnb 等）是**反例清单**：`handleSave` → `didTapSave`、`AIRAccount` → `Account`、缩略词大小写规则……

清单更好执行，但列不全且会误伤。我们选了判据 + 一个明确划定范围的「可接受词表」。**代价**是判断成本更高（靠人工评审）。这条在 AI 场景下是否更优，目前**没有证据**，属价值判断。

### 差异 6：「完整」的定义
- 市面：lint 到 0 = 完成。
- 我们：整改手册第 1 节的 **9 条验收全部满足**才算完整，且 `remediate.sh` 会**明确拒绝把「只修了格式」当作完成**。

这条对应一个真实痛点：格式化不碰命名、文档、魔法值、语言约束，而后者恰是抱怨的重点。

---

## 4. 需要补充的（按价值排序）

### P0-1：测试框架代际 —— 我们已落后一个世代
**事实**（WWDC 2026 主题 = *Migrate to Swift Testing*）：Swift Testing 自 Xcode 16 / Swift 6 起随工具链提供，官方推荐**新测试一律用它**，XCTest 只保留三类场景（UI 自动化、性能测试、ObjC 异常）。Xcode 27 默认开启互操作性，Swift 6.4 工具链已支持。

**我们的现状**（实测）：第 6 章与全文**零处提及** Swift Testing / `@Test` / `#expect`。而现有规则**在新框架下不成立或需改写**：

| 现有规则 | 依据的 SwiftLint 规则 | Swift Testing 下的对应物 |
| --- | --- | --- |
| 测试用 `XCTUnwrap` 而非强制解包 | 正文 6 + S6 | `try #require(...)` |
| 断言必须带失败说明 | `xctfail_message` | `#expect` 无 message 参数（用 Comment） |
| 用专用断言 | `xct_specific_matcher` | 宏不适用，一条 `#expect` 取代 40+ 断言 |
| 测试命名 | 3.7 + `empty_xctest_method`、`test_case_accessibility` | 命名规则完全不同（`@Test` + 反引号原生标识符） |

**这不只是「没写」，是四条规则集体需要重写。** 建议优先级最高。

### P0-2：拆分粒度准则（已有提案，未合入）
市面同样缺通用的粒度准则，但已有零散尝试：`faion-code-quality` 的 When to Split / When NOT to Split 双清单；针对 AI 友好性的「1000 行软上限 / 2000 行须拆 / 3000 行红线」分层建议；以及「为了降低行数而硬拆不会提高 AI 友好性」的明确警告。

我们的提案（`.workbuddy/notes/decomposition-granularity-proposal.md`）比这些更细：四条判据 + 九种碎片形态 + 「轴是变化而非概念」的定性判据 + 实测基线。**且已有上游约束**（DEC 计划的 `T-DEC-51`「先起名，再拆」）可吸收。

### P1-1：视图层（SwiftUI）规范 —— 我们零覆盖，市面重度覆盖
市面 agent 类方案的共识清单（多处独立提到，非孤例）：
- 视图体不超过一屏；抽 `@ViewBuilder` / 子视图 / `ViewModifier`
- 状态与副作用放 view model，**body 内不做重活**
- `ForEach` 用稳定标识；避免 `AnyView` 除非真需类型擦除
- UIKit 互操作只包**单个**控件（`UIViewRepresentable`），不包整条流程
- 依赖从构造器注入，不用单例 / ServiceLocator
- `@MainActor` 用在涉及 UI 状态处，非到处撒

我们 17 类缺陷里**没有任何一类覆盖视图层**。对一个 macOS 客户端工程（UGDockNative 有 SwiftUI 代码）这是实质缺口。

### P1-2：性能陷阱清单 —— 编译通过但运行时崩塌的那类
市面有非常具体的条目（来自实际工程笔记），例如：大字符串上 `string.count` 是 O(n)、bridged NSString 上 `index(_:offsetBy:)` 每次 O(n)、`ensureLayout(forCharacterRange:)` 会废掉非连续布局、正则/高亮范围要截断上限。

这类缺陷的共性是：**编译器不报、lint 不报、测试通常也不报**，只在高负载下暴露。我们完全没覆盖。

### P1-3：agent 反馈闭环（防「同一错犯第二次」）
`swift-code-reviewer-skill` 有一个我们完全没有的机制：**检测重复模式** —— 同一规则在同一工程触发 ≥2 次，即判定为「复发性模式」，自动起草一条项目级规则来防止复发。

我们的 `verify_consistency.sh` 是防**自己在内部漂移**，不是防**被整改的工程反复犯同一错**。两者正交。这条与我们「让 AI 少犯错的规范」定位高度契合。

### P2-1：`file_length` 的「三重缺口」（小，但真实）
实测：`assets/swiftlint.yml` 配了 `file_length: warning 700 / error 1200`，但
- 正文 **零处**提到 `file_length` 或文件行数上限（5.8 表只有函数行数/类型行数/复杂度/参数个数四行）；
- `verify_consistency.sh` **不检查**这一项（它检查 lineLength / indentation / indentSwitchCase / type_body_length）。

于是出现：**配置里在生效、规范正文没声明、自检也不覆盖**。使用者读规范不知道有这条；同时它恰好是「粒度」的一个维度 —— 与 P0-2 相关。

（另注：5.10 只要求「一个文件一个主要类型」，没有文件行数表达。）

### P2-2：规则未导出成 agent 友好的精简清单
Airbnb 官方 AI skill 只做一件事：**总结「不可自动修复」的最佳实践**。这正是我们最该有的形态 —— 我们的规则质量高，但散在 724 行正文的第 3/4/5 章里，agent 每次要读全量。

建议导出一份「AI 前置约束」精简清单（只含：不可自动修复的 MUST + 高频 AI 错误），进 `SKILL.md` 或独立 `references/`。这与第 4 轮结论一致（**前置约束 > 事后检测**）。

### P2-3：语言特性深度（待评估）
市面 agent 方案在提 Swift 6 时代的：**typed throws**、`Sendable` 约束、strict concurrency。我们 5.5 有并发章节，但深度是否覆盖 6.x 的严格并发模式**未核实**，标为待评估而非缺口。

---

## 5. 一条反向发现：上限严 + 下限缺 = 结构性鼓励碎片化

把阈值横向排开（这是我们与市面分歧最量化的一处）：

| 指标 | 本规范 | 市面（实测自一个真实 macOS 工程的 CLAUDE.md） | 差值 |
| --- | --- | --- | --- |
| 单函数行数 | **60**（error 100） | 160（error 250） | 严 2.7× |
| 单类型行数 | **300**（error 500） | 1100（error 1500） | 严 3.7× |
| 圈复杂度 | **15**（error 25） | 40（error 60） | 严 2.7× |
| 单文件行数 | 700（error 1200，**未进正文**） | 文件级用 1000/2000/3000 分层 | 量级接近 |

我们是**偏严的一侧**。而市面对「AI 友好性」给出的结论恰恰相反 —— 主张**放宽**上限（locality over hyper-abstraction），理由是 AI 需要的是「清晰边界」而不是「碎片」。

两边对「粒度」的态度因此相反：
- 我们：上限卡得很紧，**无下限**。
- 市面 AI 派：上限放宽，靠**边界清晰度**（文件名 / 类型名 / 接口表达语义）。

**风险**：严上限 + 零下限，规则只朝「更碎」施压。AI 在 60 行 / 300 行的硬约束下，最省力的合规动作就是拆 —— 而拆出来的东西**仍然 0 违规**。这不否定现有阈值（我们工程实测 9% 文件 > 300 行，存量确实偏臃肿），但说明**只补下限、不动上限**可能不够；两者是一对，应一起讨论。

---

## 6. 本次核实到的事实与出处

**本机实测（2026-09-15）**
| 项 | 命令 | 结果 |
| --- | --- | --- |
| Swift 工具链 | `swift --version` | 6.4（swiftlang-6.4.0.34.1） |
| swift-format | `swift format --version` | 输出 `main`（不按语义化版本发布） |
| SwiftLint | `swiftlint version` | 0.63.2（模板注释写「verified against 0.63」，一致） |
| nicklockwood SwiftFormat | `which swiftformat` | 未安装 |
| Swift Testing 提及次数 | `grep -rn -E "Swift Testing\|@Test\|#expect" references/*.md SKILL.md` | **0** |
| file_length 在正文 | `grep -rn "file_length" references/*.md` | **0**（模板里有 700/1200） |
| 自检覆盖的阈值 | `grep -nE "lineLength\|line_length\|type_body" scripts/verify_consistency.sh` | 行长 / 缩进 / 两个开关 / type_body；**不含 file_length** |

**市面事实的出处**
- Airbnb Swift Style Guide（含 guiding tenets、SPM 插件、**官方 AI skill** 声明）：`github.com/airbnb/swift`
- Apple swift-format（官方格式化器）：`github.com/swiftlang/swift-format`
- nicklockwood SwiftFormat（社区，与上者同名不同物）：`github.com/nicklockwood/SwiftFormat`
- Swift API Design Guidelines：`swift.org/documentation/api-design-guidelines`
- WWDC 2026「Migrate to Swift Testing」：`developer.apple.com/videos/play/wwdc2026/267/`
- Swift Testing 与 XCTest 边界（UI/性能/ObjC 异常留在 XCTest）：`drizz.dev/post/swift-testing-framework`
- `swift-code-reviewer-skill`（七阶段 + agent loop feedback）：npm 包页
- `faion-code-quality`（When to Split / When NOT to Split）：`skillmd.ai`
- AI 友好性与文件行数的分层建议（1000/2000/3000）：`jiyx.com` 技术文
- 「Locality over Hyper-Abstraction」等 AI 可读性论点：`innovatixinc.com`
- `${...}` 形式的项目级 CLAUDE.md 实例（含性能陷阱条目）：`github.com/yordis/TablePro`

**未核实 / 需谨慎的**
- 市面 agent 类方案多为**社区实验**，不是标准。上面列它们是为了说明「方向已被探索」，不是「应该照抄」。
- 我们的命名判据 vs 市面的反例清单，**哪个对 AI 更有效没有证据** —— 属价值判断，不建议据此改动。
- Swift 6 严格并发 / typed throws 在本规范的覆盖深度**未逐条核实**。

---

## 7. 建议的下一步（三选，未执行）

1. **只补 P0-1**（测试框架代际）：这是唯一「已明确落后」的项，且有官方出处。改动局限在第 6 章 + 3.7 + 配置模板的规则集，不动架构。
2. **P0-1 + P0-2 一起**（代际 + 粒度）：粒度有现成提案与上游 `T-DEC-51`，可一并合入。
3. **先做 P2-2**（导出 AI 前置约束精简清单）：成本最低、与「默认生效」定位最契合，且能顺带暴露「哪些规则其实不可自动检查」。
