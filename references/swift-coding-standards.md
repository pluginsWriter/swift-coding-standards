# Swift 编码规范（通用版）

> 本文件是**跨项目通用**标准，不绑定任何具体工程。项目特有的补充（模块结构、错误码体系、领域术语、既有基线）应写在项目自己的 `CODING_STYLE.md` 中，并声明遵循本标准。

| 项目    | 内容                                                                                                   |
| ----- | ---------------------------------------------------------------------------------------------------- |
| 版本    | v1.5.6                                                                                                 |
| 适用范围  | 所有 Swift 工程：Swift Package、App、命令行工具、C/Objective-C 互操作层                                               |
| 配套模板  | `assets/swift-format.json`、`assets/swiftlint.yml`                                                    |
| 自动化脚本 | `scripts/bootstrap_swift_style.sh`、`scripts/remediate.sh`、`scripts/verify_member_spacing.sh`          |
| 配套文档  | `references/comment-standards.md`、`references/defect-catalog.md`、`references/naming-antipatterns.md` |

---


## 0. 这份规范解决什么问题

先看**缺陷全景，**&#x4E0B;表每一行都在实际工程（`UGDockNative`，188 个源文件 / 17K 行）中被检出并计量过，检测命令见 `references/defect-catalog.md`。第 17 类为 2026-09-11 新增，实测值为当日在 202 个源文件上重扫所得。

| #  | 缺陷类别       | 典型表现                                        | 能否机器检出 | 该工程实测                |
| -- | ---------- | ------------------------------------------- | ------ | -------------------- |
| 1  | 命名生涩       | 生僻英文词、自造缩写、单字母、无法判断对象                       | 部分     | `identifier_name` 25 |
| 2  | 命名过长       | 55 字符的常量名，说明该拆类型                            | 部分     | 同上（同类规则上限 50）        |
| 3  | 一行塞多语句     | `;` 连写；一行多个 `case` / 多个键值对                  | 是      | 1074                 |
| 4  | 花括号该换行没换行  | `if x { a; b }`、`defer{...}`                | 是      | 685                  |
| 5  | 公开 API 无文档 | `public` 声明缺 `///`                          | 是      | 79                   |
| 6  | 强制解包族      | `!`、`try!`、`as!`、隐式解包可选                     | 是      | 50 / 21 / 7 / 7      |
| 7  | 类型与函数过大    | 608 行 actor、130 行函数                         | 是      | 7 + 10               |
| 8  | 复杂度过高      | 单函数圈复杂度 47（上限 15）                           | 是      | 6                    |
| 9  | 数据打包失当     | `case apply(String, X)`、3 个以上成员的元组          | 部分     | 18 + 10              |
| 10 | 魔法字符串与数值   | 257 处协议字段字面量、重复的 `["fit","fill","stretch"]` | 否      | 26 个文件               |
| 11 | 可选值误用      | `Bool?`、`var x: T? = nil`                   | 是      | 5 + 5                |
| 12 | 修饰符顺序      | `nonisolated public` 顺序不一致                  | 是      | 11                   |
| 13 | 冗余代码       | 可自动合成的 init 手写了一遍                           | 是      | 4                    |
| 14 | 并发逃逸未说明    | `@unchecked Sendable` 12 处                  | 否      | 12                   |
| 15 | 测试断言过弱     | 断言缺失败说明、用通用断言代替专用断言                         | 是      | 49 + 26              |
| 16 | 行长失控       | 最长 315 列                                    | 是      | 959                  |
| 17 | 成员间缺分隔空行   | `}` 与下一个成员声明之间没有空行，代码挤成一块                      | 是（非 swift-format / SwiftLint） | 374（Sources）/ 329（Tests） |

本规范给出**可判定、可自动执行**的统一答案：什么必须多行、什么允许单行、命名该用什么词、体量上限是多少。

两条贯穿全文的原则：

- **判据优先于清单。** 规则尽量写成「怎么判断」而不是「禁用哪些词」，因为清单永远列不全，且会误伤可读写法。
- **机器能查的不要靠人自觉。** 缺陷表标为「能机器检出」的类别都配了自动检查命令（见 `references/defect-catalog.md` 第 1 节）：格式与语义分别交给 `swift-format` / `SwiftLint`。唯一的例外是第 17 类**成员间缺分隔空行** —— 这两类工具都没有该规则，由 `scripts/verify_member_spacing.sh` 承担（见 4.7）。

> 此处刻意**不写「N 类交给工具」这类数字**：它曾与实际条目数脱节（正文写 12 类、表格里其实 11 类标「是」），而按行数一数就知道的结论不值得再维护一份副本。

---


## 1. 权威依据

逐条挂靠下列来源。凡本文件与来源冲突，以来源为准并修正本文件。

| 编号 | 来源                                                                                                                           | 性质                      | 用途                                  |
| -- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ----------------------------------- |
| S1 | [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)                                    | Apple / Swift 官方        | 命名、参数标签、文档注释、词汇选择的**唯一权威**          |
| S2 | [The Swift Programming Language](https://docs.swift.org/swift-book/)                                                         | Apple 官方语言参考            | 语言语义、可选值、并发、错误处理                    |
| S3 | [swift-format](https://github.com/swiftlang/swift-format)                                                                    | Apple 官方格式化器            | 缩进、断行、花括号、分号、import 顺序              |
| S4 | [Standard Library Programmers Manual](https://github.com/swiftlang/swift/blob/main/docs/StandardLibraryProgrammersManual.md) | Swift 官方（stdlib 范围）     | 缩进、行长、断行、代码组织                       |
| S5 | [Google Swift Style Guide](https://google.github.io/swift/)                                                                  | 行业权威（**非官方**）           | S1/S3 未覆盖处的格式补充                     |
| S6 | [LinkedIn Swift Style Guide](https://github.com/linkedin/swift-style-guide)                                                  | 行业参考（**非官方**，CC BY 4.0） | 数据建模、可选值、`guard`、注释与文件级细则（采纳项见 1.3） |

**规范用语（RFC 2119）**：`必须 / MUST`（违反即阻断合入）、`禁止 / MUST NOT`、`应当 / SHOULD`（允许有据可查的例外）、`可以 / MAY`。

### 1.1 Swift 官方没有单一格式标准

Swift 官方发布了**命名**标准（S1）和**格式化器**（S3），但没有发布唯一的、覆盖全部格式细节的官方风格指南。因此本标准：

- 命名、文档、API 形态 → 100% 采用 S1；
- 格式 → 以 S3（Apple 官方格式化器）的**默认行为**为准，用 `.swift-format` 固化；
- S1/S3 未覆盖处 → 采用 S5，并逐条标注来源。

「我们团队就觉得这样好看」不能成为偏离 S1/S3 的理由。

### 1.2 官方依据的本地快照与引文纪律

**规范正文不联网。** 上述来源在正文中只承担「可追溯」职能：第 3–6 章的规则已逐条转述并附通用示例，运行时读取的是本文件，不会请求任何 URL。

快照**随 skill 内置分发**（`references/official/`），集成、复制、移动后都无需联网：

- **上游会消失** —— S4 原先指向 `docs/Style.md`，该文件已从 `swiftlang/swift` 所有分支与标签移除（实测 404），内容并入 `docs/StandardLibraryProgrammersManual.md`。
- **网络不可靠** —— 实测 `raw.githubusercontent.com` 存在整段时间的连接失败与挂起，企业网络中常被封禁。
- **版本必须确定** —— 同一 skill 版本应对应同一份规范文本。若改为集成时下载，同一版本在不同机器上会得到不同文本，「引文逐字可检索」这条纪律的结论将不可复现。

```bash
# 集成后自检（纯离线，秒级）
bash <skill-dir>/scripts/verify_citations.sh
bash <skill-dir>/scripts/fetch_official_sources.sh --status

# 维护者巡检（需要网络，只报告、不修改）
bash <skill-dir>/scripts/fetch_official_sources.sh --freshness
```

**引文纪律**：正文中凡以引号或斜体标注为原文的句子，必须能在 `references/official/` 的快照中逐字检索到，由 `verify_citations.sh` 强制检查。**转述与改写一律不加引号** —— 把改写句伪装成原文是最难被发现的规范缺陷。来源明细与许可见 `references/official/SOURCES.md`。


### 1.3 S6 的采纳范围与冲突取舍

S6 不是官方文档，且与 S1/S3 存在实质冲突。**只采纳下表「采纳」列，其余一律以 S1/S3 与本标准为准。**

| 议题                             | S6 的主张                                                     | 本标准         | 处置                                                                                |
| ------------------------------ | ---------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------- |
| 关联值必须具名                        | 必须写 `case hunger(hungerLevel: Int)`，不能写 `case hunger(Int)` | 同           | **采纳**（5.2）                                                                       |
| 元组成员数                          | 3 个以上成员改用 `struct`                                         | 同           | **采纳**（5.2）                                                                       |
| `switch` 的 `default`           | 有限枚举不得用 `default`；不可达的 `default` 应 `throw`                 | 同           | **采纳**（5.4）                                                                       |
| `unowned`                      | 禁止                                                         | 同           | **采纳**（5.1）                                                                       |
| 测试中强制解包                        | 用 `XCTUnwrap`                                              | 同           | **采纳**（第 6 章）                                                                     |
| 访问修饰符省略 `internal`             | 默认值，不必写                                                    | 同           | **采纳**（5.3，存量不强制改）                                                                |
| 文件尾换行 / 无行尾空白                  | 必须                                                         | 同           | **采纳**（5.10）                                                                      |
| `//` 后留空格、注释独占一行               | 必须                                                         | 同           | **采纳**（5.7）                                                                       |
| 文档注释形式                         | 用块注释 `/** */`                                              | 用 `///`     | **不采纳** —— S1 与 S3 的 `UseTripleSlashForDocumentationComments` 均为 `///`，且 S3 禁止块注释 |
| 行长上限                           | 160 列                                                      | **120 列**   | **不采纳** —— 160 是 2018 年的历史取值；120 配合 4 空格缩进（2026-09-11 调整，见附录 C v1.5）                    |
| 单行 `guard ... else { return }` | 禁止                                                         | 允许（4.4 白名单） | **不采纳** —— 高频早退出场景单行更易读，且 S1/S3 无禁止                                               |
| 枚举简写 vs 类方法简写                  | 允许 `.person`，禁止 `.white`                                   | 无限制         | **不采纳** —— 该条已被现代 Swift 惯用法取代                                                     |
| 用 `+=` 追加数组                    | 禁止                                                         | 无限制         | **不采纳** —— 该性能理由在现代 Swift 已不成立                                                    |

---

## 2. 执行方式与强制等级

| 等级         | 含义          | 检查手段                                                              | 未通过后果 |
| ---------- | ----------- | ----------------------------------------------------------------- | ----- |
| 阻断（MUST）   | 违反即不合规范     | `swift format lint --strict` + `swiftlint --strict` + Code Review | 不得合入  |
| 警告（SHOULD） | 应遵守，例外需说明理由 | 同上（warning 级别）                                                    | 需评审确认 |
| 建议（MAY）    | 可选优化        | Code Review                                                       | 不影响合入 |

两条分工原则：

- **机器修复格式，人评审语义。** 第 4 章的格式规则由 `swift-format` 机械处理，不进入人工争论；人工评审聚焦第 3 章命名、第 5 章设计与第 0 章表格中「不能机器检出」的项。
- **工具是检查者，不是强制执行者。** 格式的合法来源有两个：工具排版与人工排版。规则见 4.0。

---

## 3. 命名规范

> 权威：S1。以下为中文转述 + 通用示例。  
> **引文规则**：加引号或斜体者为原文，须能在 `references/official/` 快照中逐字检索到；转述与改写一律不加引号。


### 3.1 判据：只针对「读不懂」，不针对「不眼熟」

命名是否合格，**只用一条标准判断**：

> **遮住定义，只看调用点，一个不熟悉本模块的同事能否说出这行在做什么？**

不能，就是缺陷。真正会导致「读不懂」的只有三类：

1. **生僻英文词** —— 读者需要查词典才能理解（`reify`、`thunk`、`amortize`、`hydrate`、`saga`）。
2. **自造缩写与单字母** —— 只有作者或本团队能还原（`aniDur`、`srtAnmating`、`l`、`r`、`w`、`h`、`n`）。
3. **对象或返回值无从判断** —— 名字没有提供任何消歧信息（重名、语序错乱、词性错）。

**反过来，有一批常用词与高频缩写明确可以接受，不得以「命名生涩」为由要求重命名**。完整可接受词典以 `naming-antipatterns.md` 第 0 节为**唯一权威**，本文件只引用、不复制 —— 多处副本曾导致 `drain` 在词典与整改手册间漂移（2026-09-11 修正）。

理由：这些是**中文开发者普遍熟悉的常用词与高频缩写**，含义在上下文中是确定的。把它们当缺陷只会制造大量无意义的重命名和 diff 噪音，而不会提升任何一处调用的可读性。**规范的成本必须换来看得见的收益。**

> 只有当同一个作用域内出现两个以上语义不同的同类词（例如三个不同含义的 `resolve`），或类型名无法补全对象导致调用点歧义时，**才**需要改名。这类判断见 3.3 第 5、6 条。

四条 S1 原文是全部命名判断的基础：

- `Clarity is more important than brevity.` —— 清晰优先于简洁。
- `Clarity at the point of use.` —— 可读性在**调用点**，不在定义处。
- `Avoid obscure terms.` —— 官方原文：
  > *Don't say “epidermis” if “skin” will serve your purpose.*
- `Include all the words needed to avoid ambiguity.`（补足消歧所需的所有词）与 `Compensate for weak type information.`（为弱类型信息做补偿）—— 参数类型是 `String`、`Int`、`UUID`、`Data` 时，标签必须补足语义；宁可 `removeDevice(deviceID:)` 也不要 `remove(id:)`。


### 3.2 大小写与词形（MUST）

| 对象                    | 规则             | 正确                                        | 错误                         |
| --------------------- | -------------- | ----------------------------------------- | -------------------------- |
| 类型、协议                 | UpperCamelCase | `HIDChannelSelection`、`DisplayMode`       | `hidChannelSelection`      |
| 方法、属性、参数、局部变量、枚举 case | lowerCamelCase | `maximumRetryCount`、`deviceID`            | `MaximumRetryCount`        |
| 布尔                    | 读作对接收者的断言      | `isCancelled`、`supportsFeature`、`isEmpty` | `cancelledFlag`、`feature`  |
| 缩写（API 既定者除外）         | 全大写或全小写，不混排    | `deviceID`、`usbRegistryID`、`URL`          | `deviceId`、`UsbRegistryId` |

布尔命名的依据是 S1 原文：*Uses of Boolean methods and properties should read as assertions*（布尔方法与属性应读作对接收者的断言）。

**长度也必须正常**：标识符短于 2 个字符或长于 50 个字符都属于缺陷。过短见 3.5；**过长通常说明这个类型该拆了**，而不是该起个更长的名字：

```swift
// 不好：55 字符，读者无法在调用点解析
let configurationPersistenceApplicationSupportNotAbsoluteFileURL = ...
// 好：先拆类型，再给一个可读的短名
enum ConfigurationError { case persistencePathNotAbsolute }
```


### 3.3 方法与函数（MUST）

1. **读作符合语法的英语短语**：`deviceSnapshot(deviceID:)`、`removeDevice(deviceID:)`。
2. **有副作用的方法用祈使动词**：`start`、`stop`、`apply`、`remove`、`replace`、`insert`。原文：*Those with side-effects should read as imperative verb phrases*。
3. **工厂方法用 `make` 前缀**（原文：*Begin names of factory methods with* “make”）。禁止 `create`、`build`、`with...` 前缀：
   ```swift
   static func makeBackup(configuration: Config) -> Backup   // 必须
   static func createBackup(configuration: Config) -> Backup // 禁止
   ```
4. **不加 `get` 前缀**（社区通行约定，S1/S5 均无明文，本标准采纳）：属性直接命名（`var modes: [DisplayMode]`）；需要计算则 `func modes(displayID:)`，而非 `getModes`。
5. **不做原地修改 / 返回新值的「分词强制」。** 不再要求返回新值的变体必须写成 `-ed` / `-ing` 分词（`applied` / `applying`）—— 对非母语读者，这两种词形恰恰是最难区分的。改为：
   - **硬要求**：同一类型内同时存在「改自身」和「返回新值」两种变体时，**调用点必须能一眼分辨哪个会改接收者**。
   - 表达方式任选：`makeXxx(...)`、`xxxCopy(...)`、`xxx(byApplying:)`、或直接给结果一个不同的名字。**只有一种变体时不加任何后缀。**
   ```swift
   display.apply(change)                 // 原地修改
   let updated = display.makeUpdated(byApplying: change)   // 返回新值
   let updated = display.display(applying: change)         // 同样可以
   ```
6. **泛化动词不必强行补宾语。** 词典收录的泛化动词（完整清单见 `naming-antipatterns.md` 第 0 节，不在此复制）单独出现时**不再一律要求改名**。判据只有一条：**调用点会不会产生歧义**。仅在下述情况必须补足对象：
   | 情形                                 | 处置                                          |
   | ---------------------------------- | ------------------------------------------- |
   | 同一类型/作用域内出现两个以上语义不同的同类词            | 补宾语区分（`releaseLock()` / `releaseArchive()`） |
   | 类型名无法补全对象（如 `Helpers.resolve(_:)`） | 补宾语（`resolveDevice(id:)`）                   |
   | 参数含义无法从签名看出                        | 补参数标签（见 3.4）                                |
   | 以上都不成立                             | **保持简洁，不改**                                 |

### 3.4 参数标签（MUST）

- **调用点必须能读懂**：`synchronize(deviceID:)` 而非 `sync(_:)`。
- **省略无信息量的词**：`remove(_ member:)` 而非 `removeElement(_:)`。
- **默认参数表达「通常如此」**：`descriptorByteLimit: Int = .default`。
- **禁用无标签的裸 `String` / `Int` / `UUID` / `Data` 参数**（C ABI 除外）。
- 首个参数若与类型名重复，省略标签：`insert(_ element: Element, at index: Int)`。

### 3.5 缩写与术语（MUST NOT）

| 类别         | 规则                             | 示例                                                            |
| ---------- | ------------------------------ | ------------------------------------------------------------- |
| **自造缩写**   | 禁止 —— 只有作者或本团队能还原              | `aniDur`、`srtAnmating`、`vc`、`btn`                             |
| **单字母标识符** | 禁止（`i`、`j` 在作用域 ≤ 3 行时可作循环计数器） | `l`、`r`、`w`、`h`、`n`、`c`、`p`、`d`                               |
| **生僻黑话**   | 禁止 —— 母领域有确切含义、借来后语义漂移，且无项目内定义 | `reify`、`thunk`、`amortize`、`hydrate`、`saga`                   |
| **行业既定缩写** | 可以                             | `URL`、`ID`、`USB`、`HID`、`HTTP`、`JSON`、`UUID`、`API`、`CPU`、`ABI` |
| **高频紧凑写法** | 可以（含义固定、上下文确定，见 3.1）           | `cfg`、`msg`、`req`/`resp`、`ctx`、`u16`                          |

**领域术语必须有定义**：项目自造的名词（如「预算」「代际」「排空」）应登记在项目术语表；未登记又被当专业名词使用的词属于黑话。完整反模式清单与替换对照见 `references/naming-antipatterns.md`。

**与工具对齐（2026-09-11）**：SwiftLint 模板的 `identifier_name.excluded` 与本节一致 —— `i`、`j`（≤ 3 行循环计数器）、`x`/`y`/`z`（坐标）、`u`/`t`/`v`/`a`/`b`（解构与局部临时值）、`id`/`ids` 不参与长度检查；其余单字母仍按本表禁止。

### 3.6 协议、类型与泛型（MUST）

协议命名看用途 —— S1 原文分两句，均以 *Protocols that describe* 开头：描述「是什么」用名词（`Collection`、`DeviceRepository`），描述「能做什么」用 `-able` / `-ible` / `-ing` 后缀（`Sendable`、`Decodable`、`ProgressReporting`）。

另外两条：

- 泛型参数：有明确角色时用描述性名字（`Element`、`Key`、`Value`），无意义时用 `T`、`U`。
- 协议名不加 `Protocol` 后缀，实现类型名不加 `Impl` 后缀。

### 3.7 测试命名（SHOULD）

用一句话说&#x6E05;**「什么条件下发生什么」**，不要照抄被测方法名；也不要堆砌从句 —— 过长反而更难读。

```swift
func testNormalize() { ... }                                   // 不好：看不出验证什么
func testRemovesReportIDWhenPayloadHasLeadingID() { ... }      // 好：条件 + 行为
```

---

## 4. 格式规范

> 权威：S3 默认行为 + S5 补充。全部规则都可由 `.swift-format` 校验（`swift format lint`）。  
> **人工排版与工具排版同等有效**：允许开发者手动排版。只要不违反本章 MUST 规则，工具**不得覆盖**人工排版结果。

### 4.0 人工排版与工具的边界（MUST）

格式有**两个合法来源**：`swift format` 的输出、以及开发者手写的排版。两者冲突时，按下面处理：

| 情形                                        | 处理                              |
| ----------------------------------------- | ------------------------------- |
| 人工排版违反本章 MUST 规则（分号、块内多语句压行、`defer{`、缺空格、**成员之间缺分隔空行**） | **必须改** —— 这类问题没有主观空间。前四类 `swift format lint` 会报；**成员间空行 swift-format 与 SwiftLint 都查不出**，须另跑 `scripts/verify_member_spacing.sh`（见 4.7） |
| 人工排版只在 MUST 之外的位置与工具默认不同（手动断行、对齐、**语句组内部是否空行**）    | **保留人工排版**，不得判定为违规              |
| 需要长期保留某处人工排版                              | 在该声明前加 `// swift-format-ignore` |

三条硬性要求：

1. **`--in-place` 不是提交前必做动作。** 它只在开发者主动运行并接受结果时使用；CI 与钩子只做 `lint` 检查，**禁止**自动改写源码。
2. **不得覆盖既有换行。** 模板中 `respectsExistingLineBreaks: true`（S3 默认即为 `true`）—— 开发者刻意拆开的行不会被合并回去。修改模板时不得关掉此项。
3. **局部豁免用 `// swift-format-ignore`。** 实测：该注释会让工具**同时**跳过下一条声明的格式化与 lint 检查，是唯一被支持的豁免机制。

```swift
// swift-format-ignore
func alignedMatrix( _ a: Int,  _ b: Int ) { print(a); print(b) }   // 手动排版，工具不会改写
```

### 4.1 一行一条语句，禁止分号（MUST）

S3 规则 `DoNotUseSemicolons`。业务代码中出现分号即为违规。

```swift
// 禁止
self.reportID = reportID; self.requestMessageType = requestMessageType; self.timeout = timeout

// 必须
self.reportID = reportID
self.requestMessageType = requestMessageType
self.timeout = timeout
```

同样适用于 `switch` case 体、闭包体、初始化器赋值：

```swift
// 禁止
case .output(let data): type = kIOHIDReportTypeOutput; payload = data; isRead = false

// 必须
case .output(let data):
    type = kIOHIDReportTypeOutput
    payload = data
    isRead = false
```

另外两条同类规则（均由 `swift-format` 强制）：

- **一行一个 `case`**（`OneCasePerLine`）：`case fill, fit, stretch` 应各占一行。
- **一行一个变量声明**（`OneVariableDeclarationPerLine`）：`let width: Int?; let height: Int?` 拆成两行。

### 4.2 花括号（MUST）

1. **K\&R / 1TBS 风格**：左花括号与声明同行，右花括号独占一行；`else` / `catch` 与右花括号同行。禁止 Allman（左括号另起一行）。
2. **`{` 与关键字之间必须有一个空格**：`defer {`、`if cond {`、`guard cond else {`。**禁止 `defer{`、`if x{`、`else{`**。
3. **所有控制流语句必须带花括号**，即使只有一条语句；`if` / `guard` / `while` / `for` / `repeat` 无花括号即为违规。
4. **块内出现 2 条及以上语句时，禁止压成一行。**

```swift
// 禁止
if queues[key] == nil { queues[key] = []; return }
// 必须
if queues[key] == nil {
    queues[key] = []
    return
}
```

### 4.3 `defer` 的书写（MUST）

- 语法形式**必须**为 `defer { ... }`，关键字与花括号之间有且仅有一个空格。
- **块内只有 1 条简单语句时，可以单行**：`defer { lock.unlock() }`、`defer { IOObjectRelease(service) }`。
- **块内含 2 条及以上语句时，必须换行展开**：
  ```swift
  // 禁止
  defer { try? left.close(); try? right.close() }
  // 必须
  defer {
      try? left.close()
      try? right.close()
  }
  ```
- **禁止 `defer` 与前置语句挤在同一行**（`try await acquire(); defer { release() }` 必须拆开）。

### 4.4 允许的单行形式白名单（MAY）

以下**单语句**形式允许单行；除此之外，只要出现第二条语句就必须换行。

| 形式               | 允许单行的条件                                            | 示例                                          |
| ---------------- | -------------------------------------------------- | ------------------------------------------- |
| `defer`          | 恰好 1 条简单语句                                         | `defer { lock.unlock() }`                   |
| `guard ... else` | 尾部恰好 1 条 `return` / `throw` / `break` / `continue` | `guard let device else { return }`          |
| 计算属性 / 函数体       | 恰好 1 个表达式，且不超行长                                    | `var isRunning: Bool { state == .running }` |
| `switch` case    | 恰好 1 条语句                                           | `case .stopped: return false`               |
| 闭包字面量            | 恰好 1 个表达式                                          | `queue.async { [self] in close() }`         |

**反面清单（必须展开）**：初始化器赋值组、`do/catch`、多语句 `if/else` 体、`switch` case 的多语句体、`Task { }` 多语句体、`withUnsafeBytes { }` 多语句体。

### 4.5 缩进与空白（MUST）

- **缩进与 Xcode 编辑器对齐：每个嵌套层级统一 4 个空格**（`.swift-format` 的 `indentation.spaces = 4`）。适用范围是**全部嵌套构造**，不是某一类：类型 / 函数体、`if` / `for` / `while` / `do-catch` / `guard` 的 else 块、闭包体、`switch` 的 `case`（含多层嵌套 `switch`）、`#if` 条件编译块内容。全工程唯一，**不接受项目级例外**。
  > 2026-09-11 由 2 空格调整为 4 空格（推翻 v1.4 的 2/100 决定）。动因：Xcode 编辑器默认缩进步长就是 4 空格，2 空格配置下每次回车产生的自动缩进都与格式化结果冲突，手工编码持续打架。取值仍在 S3/S4 允许范围内（Swift 官方不强制缩进宽度）。
- **`case` 相对 `switch` 缩进一级**（`indentSwitchCaseLabels = true`）。swift-format 默认会把 `case` 拍回与 `switch` 同级，**必须显式开启**才能与 Xcode 一致；多层嵌套 `switch` 每层照此 +4。
- **`#if` 条件编译块内容同样缩进一级**（`indentConditionalCompilationBlocks = true`）。注意：swift-format 的默认值本来就是缩进，**不要显式设回 `false`**（旧模板设过 `false`，与 Xcode 行为相反，2026-09-11 修正）。
- SwiftLint 侧 `indentation_width`、`switch_case_alignment` 保持禁用：缩进判定权全部交给 swift-format，避免两套工具各说各话。
- **禁止 Tab**（`tabWidth` 仅用于显示既有 Tab 文件）。
- 禁止行尾空白；禁止连续 2 个以上空行（S3 `maximumBlankLines = 1`）。
- 运算符两侧、`,` 之后、`:` 之后必须有一空格；`:` 之前无空格。

### 4.6 行长与断行（MUST）

- **单行硬上限 120 列**（`.swift-format` 的 `lineLength = 120`；`.swiftlint.yml` 的 `line_length.warning = 120`）。4 空格缩进下嵌套更深，120 列给参数列表留出合理余量；存量工程在迁移时**一次性接受全量重排**，不做两段式过渡。
- 优先用**提取中间变量**化解超长条件，而不是把条件强行折行：
  ```swift
  // 好：先拆条件
  let isConnected = source.state == .connected
  let hasCapacity = source.usedBytes < source.limitBytes
  if isConnected && hasCapacity { ... }
  ```
- 断行优先级：参数每个一行（续行相对当前语句缩进一级，即 +4）→ 逻辑运算符置新行行首 → 链式调用 `.` 置新行行首 → 字符串用多行字面量，禁止 `+` 拼接换行。

### 4.7 空行（MUST）

> 出处：S5 §Vertical Whitespace。原文："A single blank line appears in the following locations:"，其第 1 项要求类型的**连续成员**（属性、初始化器、方法、enum case、嵌套类型）之间各空一行，并只对「属性 / case」给出除外条款。

- **类型声明之间、成员之间（方法 / 初始化器 / 计算属性 / 嵌套类型）空 1 行。**
- **两个除外条款**（转述 S5 的除外项，非原文；两类都可以不空行，用于表达逻辑分组）：
  - 连续的**单行**存储属性之间、连续的**单行** enum case 之间；
  - 两个**紧密相关**的属性之间（例如一个私有存储属性与它对应的公开计算属性）。
  这两条**只豁免属性与 case**；方法、初始化器、嵌套类型没有任何例外，必须空行。
- 声明前有文档注释时，空行插在**注释块之前** —— 注释属于该声明，隔开的是前后两个成员，不是注释与声明。
- 逻辑相关的连续语句之间不空行；被注释分组的段落之间空 1 行。
- 禁止左花括号之后、右花括号之前出现空行（S3 `NoEmptyLinesOpeningClosingBraces`）。
- **检测（本规范唯一一条工具查不出的格式规则，必须单独跑）**：实测 swift-format 6.3.3 的规则集中没有「成员间空行」这一项（配置项 `maximumBlankLines = 1` 管的是**上限**即「不许连续两个空行」，不是下限），SwiftLint 0.63 同样没有对应规则。因此用本 skill 自带脚本：

  ```bash
  bash <skill-dir>/scripts/verify_member_spacing.sh <目录>...          # 只报告（只读）
  bash <skill-dir>/scripts/verify_member_spacing.sh <目录>... --fix    # 插入缺失的空行
  ```

  判据是「上一个代码行是独立的一行 `}`、与本声明同缩进、且中间没有空行」；只覆盖**有花括号体的成员**，按上面的除外条款**主动跳过**单行存储属性与 enum case，避免误报合法的属性分组。**已知漏检**：成员结尾不是 `}` 时查不到（如多行数组字面量、`#endif` 结尾）、缩进用 Tab 时可能漏（4.5 本就禁 Tab）。

### 4.8 import（MUST）

按 S3 `OrderedImports` 排序：系统框架在前，第三方 / 本包在后，同组内字典序，组间不空行。

### 4.9 其他（MUST）

- **尾随逗号**：多行集合 / 参数列表的最后一项必须带尾随逗号（`multiElementCollectionTrailingCommas`）。
- **数字字面量**：超过 4 位的十进制加下划线分组（`10_000`）；十六进制 `0x1F_4A`。
- **注释符号**：只用 `//` 与 `///`，禁止 `/* */` 块注释（`NoBlockComments`）。

---

## 5. 语言与设计约束

### 5.1 可选值（MUST）

- 禁止强制解包 `!`、禁止 `try!`、禁止 `as!`。C 互操作场景必须显式 `guard let` 并给出错误分支。
  **分工（2026-09-11 明确）**：强制解包由 SwiftLint 的 `force_unwrapping` 强制（`.swift-format` 的 `NeverForceUnwrap` 显式关闭，避免两个工具重复报告同一问题，**不要把 false 改回 true**）；`try!` 由 swift-format 的 `NeverUseForceTry` 强制；`as!` 由 SwiftLint 的 `force_cast` 强制。
- 禁止隐式解包可选 `String!`，唯一例外是 `@IBOutlet`。
- **禁止 `unowned`**（原文：*Don't use `unowned`.*）—— 它等价于「隐式解包的弱引用」，与上面两条同源。用 `weak` + `guard let`。
- 禁止对布尔做可选（`Bool?`），用独立状态枚举（`enum Availability { case enabled, disabled, unknown }`）。
- 可选变量不必写 `= nil`（`implicit_optional_initialization`）。
- 只判断存在性、不使用值时用 `if value != nil`，而不是 `if let _ = value`。
- 优先 `guard let` 早退出，避免多层 `if let` 嵌套；解包后的变量沿用原名（`guard let device = device else { ... }`）。

### 5.2 类型选择与数据建模（SHOULD / MUST）

| 场景          | 选择                    |
| ----------- | --------------------- |
| 纯数据、无引用语义   | `struct`（**默认选择**）    |
| 有限状态 / 封闭集合 | `enum`                |
| 独立生命周期或需要继承 | `final class`         |
| 需要串行化状态访问   | `actor`               |
| 跨并发边界传递     | `struct` + `Sendable` |

- `class` 若无需继承，必须加 `final`。
- **元组最多 2 个成员**（MUST）。3 个及以上必须定义具名 `struct`：官方指南原文 *If you’re returning 3 or more items in a tuple, consider using a `struct` or `class` instead.* 顺带解决 `large_tuple` 与位置参数难读两个问题。
- **关联值必须具名**（MUST）。原文：*make sure that this value is appropriately labeled as opposed to just types*。
  ```swift
  case hunger(Int)                                     // 禁止：调用点读不懂
  case hunger(hungerLevel: Int)                        // 必须
  case wallpaper([String], String, String)             // 禁止
  case wallpaper(displayIDs: [String], filePath: String, mode: WallpaperMode)  // 必须
  ```
- **不要把结构化数据塞进万能字典**（SHOULD）。跨模块传递的协议字段应定义具名类型；字面量只允许出现在序列化边界，且字段名必须来自具名常量（见 5.9）。

### 5.3 访问控制（MUST）

- `public` / `private` / `fileprivate` 必须显式写出；**`internal` 是默认值，新建代码建议省略**（存量不强制改，避免无意义 diff）。
- 不作为跨模块契约的成员一律 `private` 或 `internal`。
- 优先 `private`，`fileprivate` 需要理由（`private_over_fileprivate`）。
- **修饰符顺序统一**，以 `swiftlint` 的 `modifier_order` 为准（本模板要求 `nonisolated` 在访问修饰符之前）：`nonisolated private func f()`。

### 5.4 错误处理（MUST）

- 库边界统一抛出**项目自定义的错误信封类型**，禁止把 `NSError`、`errno`、`io_return` 等原始值直接透出到模块边界。
- 错误码由**发生错误的模块**拥有并定义；基础层不定义业务错误码。
- 禁止空 `catch`：要么转换后继续抛，要么记录后返回明确失败结果。
- **对有限枚举做 `switch` 时禁止写 `default`**。新增 case 时编译器必须报错，`default` 会吞掉这个保护。
- 语义上不可达的 `default` 应该 `throw` 或断言，而不是静默 `break`。原文：*If you have a default case that shouldn't be reached, preferably throw an error*。
- 异步只读 API 用 `async throws`；回调式 API 必须保证「恰好一次」交付。
- 禁止用错误类型表达可预期的业务分支（那是 `enum` 返回值的职责）。

### 5.5 并发（MUST）

- Swift 6 语言模式下，跨并发边界类型必须 `Sendable`；**`@unchecked Sendable` 必须在声明处注释说明封装的可变性来源**（这是第 0 章第 14 类缺陷的整改要求）。
- actor 内部状态禁止通过 `nonisolated` 暴露可变引用。
- 禁止用 `Task.sleep` 轮询代替同步；优先 `CheckedContinuation` / actor 状态 / `AsyncStream`。
- `Task { }` 捕获 `self` 时显式写捕获列表（`[self]` / `[weak self]`）。
- 禁止在 `deinit` 中调用异步或 actor 隔离代码。
- 用确定性 gate / actor 状态来测试并发，不要靠增加迭代次数复现竞态。

### 5.6 不安全指针与 C 互操作（MUST）

- `Unmanaged` / `Unsafe*Pointer` 的使用必须集中在单一类型内，不得跨文件散布。
- 每个 `allocate` 必须有配对的 `deallocate`，且必须由 `defer` 或 `deinit` 保证释放。
- `passRetained` 必须有明确的所有权转移注释，说明由谁 `release()`。
- 回调上下文必须保证在回调返回前完成数据复制。
- C ABI 导出符号使用项目前缀，且不得在无 ADR 的情况下重命名。

### 5.7 注释与文档（MUST）

完整规则见 **`references/comment-standards.md`**。核心六条：

1. **`public` / `open` API 必须写 `///` 文档注释**（S1 明文要求，SwiftLint `missing_docs`）。
2. **文档注释说明调用契约**：一句话摘要 → 详细说明（空注释行分隔）→ 参数 → 返回值 → `Throws` → `Note` / `Important` / `Warning`。
3. **参数较多用复数形式** `- Parameters:`；单个参数用 `- Parameter x:`。标识符与类型名用反引号。禁止 JavaDoc 风格的 `@param` / `@return`。
4. **实现注释解释「为什么」**，不复述代码。写清楚技术权衡、业务规则、边界条件、并发假设。
5. **注释语言项目内统一**（中文项目用中文，开源库用英文）；标识符与技术术语保持英文原文。
6. **禁止提交被注释掉的死代码**；`TODO` / `FIXME` 必须带原因并尽量关联 issue 或负责人。

```swift
/// 按设备身份与接口身份打开 HID 控制通道。
///
/// - Parameters:
///   - selection: 来自真实发现的设备与接口身份，不接受仅按 VID 构造的选择。
///   - configuration: 通道缓冲、超时与线路格式配置。
/// - Returns: 已激活的托管通道；调用方负责 `close()`。
/// - Throws: `HIDTransportError.unavailable` 当接口不存在或已被占用。
public static func open(
    selection: HIDChannelSelection,
    configuration: HIDChannelConfiguration
) async throws -> ManagedHIDReportChannel { ... }
```

### 5.8 复杂度与体量上限（MUST）

超过上限代码几乎必然难改难测。阈值由 SwiftLint 强制，**不得为了通过而调高**。

| 指标      | 上限           | 规则                         |
| ------- | ------------ | -------------------------- |
| 单函数行数   | 60           | `function_body_length`     |
| 单类型行数   | 300               | `type_body_length`         |
| 单函数圈复杂度 | 15           | `cyclomatic_complexity`    |
| 单函数参数个数 | 6            | `function_parameter_count` |

超限时的处理顺序（**不要靠加注释或拆行糊过去**）：

1. 先用**查表 / 状态枚举**替换长 `if-else` / `switch` 链 —— 多数高复杂度函数是「分支堆积」；
2. 再按职责**拆成多个私有函数**，名字要能说明各自职责；
3. 仍超限则**提取独立类型**（一个 600 行的 actor 通常是三个类型挤在一起）。

### 5.9 常量与魔法值（MUST）

- **同一个字符串字面量出现 2 次以上即为违规**，必须提取为具名常量。
- **协议字段名、模式字符串、上限数值必须具名**：
  ```swift
  // 禁止：同一批字段名在映射与校验处各写一遍，改协议必漏
  guard Set(params.keys) == ["display_id", "changes"] else { throw ... }
  // 必须
  private enum Field {
      static let displayID = "display_id"
      static let changes = "changes"
  }
  ```
- 模式 / 枚举取值不要用字符串数组判断，应定义 `enum` 并实现 `Codable`：`["fill", "fit", "stretch"].contains(mode)` 应为 `WallpaperMode(rawValue: mode) != nil`。
- 数字字面量除 `0`、`1`、`2` 外必须有具名常量或附单位注释。

### 5.10 文件级要求（MUST）

- **每个文件末尾必须有换行**（*Ensure that there is a newline at the end of every file.*）。
- **禁止行尾空白**（*Ensure that there is no trailing whitespace anywhere*）。
- 文件头只允许**统一的项目版权声明**；不写作者姓名与「最后修改日期」—— 这两项会过期且由版本控制负责。
- 一个文件只放一个主要类型；同文件的扩展用于协议实现分组，并用 `// MARK:` 标注。

---

## 6. 测试代码规范

- 测试代码在格式上遵守第 4 章全部规则；命名遵守 3.7。
- 测试必须验证**行为**，不得只验证实现细节（不要断言私有状态）。
- **断言必须带失败说明**（`xctfail_message`），避免「断言失败但看不出为什么」。
- **用专用断言**（`xct_specific_matcher`）：`XCTAssertTrue(a == b)` → `XCTAssertEqual(a, b)`。
- **测试中禁止强制解包**（原文：*Use `XCTUnwrap` instead of forced unwrapping in tests*）：`value!` 会以崩溃代替明确的失败信息。
- 并发测试使用确定性同步原语，不得靠 sleep 或增加迭代次数。
- 项目可在自己的 `CODING_STYLE.md` / `TESTING.md` 中追加测试数量、时长与禁止事项，但不得放宽本章。

```swift
// 反例
func testNormalize() { ... }
XCTAssertTrue(result)

// 正例
func testRemovesReportIDWhenPayloadHasLeadingID() throws { ... }
XCTAssertEqual(result, expected, "剥离 ReportID 后的载荷应与预期一致")
let channel = try XCTUnwrap(factory.lastCreatedChannel)
```

---

## 7. 工具链

### 7.1 官方格式化器 swift-format（S3）

- **Swift 6.x 工具链自带**：`swift format --version` 可直接使用，无需单独安装。工具链较旧时可用 `brew install swift-format` 补上。
- 配置文件 `.swift-format` 放在仓库根目录（模板见 `assets/swift-format.json`）。

```bash
# 检查（CI 与提交前钩子只做这一步，不改源码）
swift format lint --recursive --strict Sources Tests

# 自动修复：仅当开发者主动运行并接受结果时才用（见 4.0）
swift format --in-place --recursive Sources Tests
```

- 保留人工排版的手段：`// swift-format-ignore`（单条声明）、`respectsExistingLineBreaks: true`（全局不合并手写断行）。

### 7.2 静态检查 SwiftLint

配置文件名 `.swiftlint.yml`（模板见 `assets/swiftlint.yml`）。

```bash
swiftlint lint --strict --quiet
swiftlint lint --fix
```

**分工必须清晰**：`swift-format` 负责格式（第 4 章），`SwiftLint` 负责复杂度、体量、命名与语义规则（第 3、5 章）。模板已把全部格式规则显式禁用，避免两个工具给出不一致结论。两者必须同时在 CI 通过。

### 7.3 提交前钩子

```bash
swift format lint --recursive --strict Sources Tests || exit 1
swiftlint lint --strict --quiet || exit 1
```

**钩子只做检查，不得自动运行测试、构建，也不得自动改写源码**（见 4.0 第 1 条）。

### 7.4 CI 建议

两个 lint 步骤并行；格式检查失败直接阻断。CI **不得**提交自动修复结果 —— 那会绕过人工排版。

---

## 8. 迁移与落地

### 8.1 采集基线

动手之前先量化现状。**先读下面两个坑，否则数字一定是错的。**

```bash
# 格式类：必须 2>&1（输出走 stderr）+ sort -u（会重复输出）
swift format lint --recursive Sources Tests 2>&1 | grep -E '\[[A-Za-z]+\]' | sort -u \
  | grep -oE '\[[A-Za-z]+\]' | sort | uniq -c | sort -rn

# 语义类，按规则统计数量
swiftlint lint --quiet 2>&1 | grep -oE '\([a-z_]+\)$' | sort | uniq -c | sort -rn
```

**坑一：`swift format lint` 的违规输出全部走 stderr。** 用 `2>/dev/null` 会得到「零违规」的错误结论。

**坑二：它会重复输出同一条违规，实测约 3.5 倍。** 某工程 `Sources` 原始输出 1797 行，去重后仅 513 条，而该目录真实分号数为 519 —— 去重后的数才接近真相。**任何基线都必须先按 `文件:行:列:规则` 去重。**

> 直接使用脚本可省掉这些细节：`bash <skill-dir>/scripts/remediate.sh <工程目录> --check`（已内置去重，并按规则输出基线、报告与人工待办清单）。

### 8.2 分批策略

1. **第一批（纯机械、零语义风险）**：`swift format --in-place --recursive Sources Tests`，  
   一次修掉分号、花括号换行、缩进（每层 4 空格）、行长（120 列）、尾随逗号、import 顺序。  
   **动手前必须先确认工作区状态**：
   - 工作区干净 → 重排单独成一个提交，提交信息 `style: apply swift-format`。
   - **存在未提交的在制品 → 必须先把在制品单独提交**（哪怕只是暂存提交），再执行重排。  
     否则重排会改写其中绝大多数文件，逻辑改动与格式改动混成一个无法拆分、无法审阅的 diff。  
     这一步极易被忽略：只看 `git status` 有改动并不意味着「有在制品」，  
     要确认那些改动是不是别人正在进行的逻辑重构。
2. **第二批（可机器化）**：修复 lint 暴露的复杂度、体量、修饰符顺序、可选值误用、测试断言问题。
3. **第三批（需评审）**：提取魔法字符串常量、给关联值补标签、把大元组换成具名 `struct`、补 `///` 文档。
4. **第四批（需评审 + ADR）**：重命名 public API（会影响调用方与跨语言边界）。
5. **第五批（收尾）**：处理 swift-format **无法自动修**的非机械项 —— 文档注释摘要后缺空行、  
   枚举 case 一行多值、冗余初始化器、块注释、`try!`、命名。这些必须人工逐条处理，  
   不能因为「重排已跑过」就当作完成（见手册第 1 节验收标准）。

### 8.3 硬性约束

- 格式迁移属于**无行为变更**的提交，不需要新增测试；但每次提交后必须运行受影响的测试。
- 重命名与数据建模调整属于**有行为边界影响**的变更，必须声明影响范围并对受影响测试完整回归。
- **严禁把格式修改与逻辑修改混在同一个提交里。**
- 禁止为通过 lint 而放宽阈值（提高上限、关掉规则）—— 放宽阈值必须写进规范的变更记录。

---

## 附录 A 提交前自检清单

- [ ] `swift format lint --strict` 无输出；我**没有**在未确认的情况下用 `--in-place` 覆盖他人手写排版。
- [ ] `swiftlint lint --strict` 零 warning。
- [ ] 没有任何 `;` 分隔的多语句行；没有一行多个 `case` 或一行多个变量声明。
- [ ] 所有 2 条以上语句的块都已换行；`defer { ... }` 符合 4.3。
- [ ] 没有 `!` 强制解包、`try!`、`as!`、隐式解包可选、`unowned`。
- [ ] 新增方法名在调用点可读；没有自造缩写、单字母、生僻黑话。
- [ ] 新增/修改的 `public` 声明都有 `///` 文档注释（含 Throws 条件）。
- [ ] 没有新增魔法字符串；重复出现的字面量已提取常量。
- [ ] 关联值具名；元组不超过 2 个成员。
- [ ] 函数未超 60 行、复杂度未超 15、类型未超 300 行。
- [ ] 文件尾有换行，无行尾空白。

## 附录 B 规则来源速查

| 章节                       | 来源                                         | 可自动修复   |
| ------------------------ | ------------------------------------------ | ------- |
| 3.1 命名判据                 | 本标准（收敛 S1 `Avoid obscure terms`）           | 否       |
| 3.2–3.4 大小写 / 方法 / 标签    | S1                                         | 部分（大小写） |
| 3.5 缩写与术语                | S1 + `references/naming-antipatterns.md`   | 否       |
| 3.6 协议与泛型                | S1                                         | 否       |
| 3.7 测试命名                 | 本标准                                        | 否       |
| 4.0 人工排版边界               | 本标准（工具能力实测）                                | —       |
| 4.1 分号 / 一行一语句           | S3 `DoNotUseSemicolons` / `OneCasePerLine` | 是       |
| 4.2 花括号                  | S3 + S5 + S6                               | 是       |
| 4.3 defer                | 本标准                                        | 部分      |
| 4.4 单行白名单                | 本标准（**不采纳** S6 3.11.7）                     | 否（需判断）  |
| 4.5–4.9 空白 / 断行 / import | S3                                         | 是       |
| 5.1 可选值                  | S3 + S6 3.5.1–3.5.5                        | 部分      |
| 5.2 类型与数据建模              | S1 + S2 + S6 3.1.4 / 3.4.4                 | 部分      |
| 5.3 访问控制                 | S6 3.2.1–3.2.5 + SwiftLint                 | 部分      |
| 5.4 错误处理                 | S1 / S2 + S6 3.4.1 / 3.4.6                 | 部分      |
| 5.5 并发                   | S2 + 本标准                                   | 部分      |
| 5.6 不安全指针                | 本标准 + S2                                   | 否       |
| 5.7 注释与文档                | S1 + `references/comment-standards.md`     | 部分      |
| 5.8 复杂度与体量               | SwiftLint 默认阈值 + 本标准                       | 否（需重构）  |
| 5.9 常量与魔法值               | 本标准（工程实测）                                  | 否       |
| 5.10 文件级要求               | S6 1.3 / 1.4 + S3                          | 是       |
| 6 测试                     | 本标准 + S6 3.5.6 + 项目 TESTING 文档             | 部分      |


## 附录 C 变更记录

| 版本   | 日期         | 变更                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| v1.0 | 2026-09-10 | 首版：命名、格式（分号 / 花括号 / defer）、语言约束、工具链、迁移策略                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| v1.1 | 2026-09-10 | 修正 S4 死链（`docs/Style.md` 已被官方移除 → `StandardLibraryProgrammersManual.md`）；新增 1.2 官方依据的离线快照与引文纪律；更正 epidermis 误引；`get` 前缀改标为社区约定                                                                                                                                                                                                                                                                                                                                                                                    |
| v1.2 | 2026-09-10 | 明确快照**内置分发**而非集成时下载；8.1 补充两条实测计数坑；新增 `remediation-playbook.md` 与 `remediate.sh`，SKILL.md 增加「场景零」「场景五」                                                                                                                                                                                                                                                                                                                                                                                                             |
| v1.3 | 2026-09-10 | **命名规范收敛为「只针对读不懂，不针对不眼熟」**（3.1）：`normalize` / `reserve` / `perform` / `flight` / `generation` / `u16` 等常用词明确可接受；3.3.5 取消 `-ed`/`-ing` 强制；3.3.6 泛化动词放宽为「仅歧义时改名」；3.7 测试命名精简。**第 4 章新增 4.0「人工排版与工具的边界」**：允许并保留手写排版，`--in-place` 不再作为提交前必做，`// swift-format-ignore` 为唯一豁免机制（已实测）。第 5 章新增 **5.8 复杂度与体量上限**、**5.9 常量与魔法值**、**5.10 文件级要求**，5.1/5.2/5.3/5.4 补充 `unowned`、具名关联值、元组上限、枚举 `default`。第 0 章改为 **16 类缺陷全景**（基于实际工程计量）。并入 S6 并新增 1.3 冲突取舍表；新增 `references/comment-standards.md` 与 `references/defect-catalog.md` |
| v1.4 | 2026-09-10 | **缩进与行长统一为 2 空格 / 100 列**（4.5、4.6）：模板取消 4 空格 / 120 列的兼容档位，与 Swift 官方标准库、swift-format 默认值一致；1.3 的 S6 行长冲突行同步改为 100。8.2 第一批补&#x5165;**「动手前必须先确认工作区是否有未提交在制品」**—— 有则必须先单独提交，否则逻辑改动与格式改动会混成不可拆分的 diff（本轮实际踩中）；第五批改为「处理 swift-format 无法自动修的非机械项」。同步更新 `.swift-format` 与 `.swiftlint.yml` 模板                                                                                                                                                                                                                            |
| v1.5 | 2026-09-11 | **缩进全面对齐 Xcode 编辑器：每层 4 空格 / 行长 120 列，开启 `indentSwitchCaseLabels` 与 `indentConditionalCompilationBlocks`**（4.5、4.6），**推翻 v1.4 的 2/100 决定**。适用**全部嵌套构造**（类型/函数体、if/for/while/do-catch/guard、闭包、switch 的 case 含多层嵌套、#if 块内容），不是只改 switch。动因：Xcode 编辑器默认缩进步长为 4 空格，2 空格下每次回车都与格式化结果冲突；swift-format 默认把 `case` 拍回与 `switch` 同级（`indentSwitchCaseLabels` 默认 false，必须显式开启）；`indentConditionalCompilationBlocks` 默认为 true 但旧模板显式设过 false，一并修正。实测 swift-format 6.3.0 支持上述两项配置（S3 配置文档有正式条目）；SwiftLint 侧 `switch_case_alignment`、`indentation_width` 保持禁用，无冲突。另实测：短签名下的花括号独占行会被 swift-format 自动合并，长签名（合并后超行长）的花括号独立成行是格式化器自身决策且 lint 不报，属合法形态。同步更新两个模板资产与 SKILL.md |
| v1.5.1 | 2026-09-11 | **一致性修正（对照 `docs/skill-review/2026-09-10-swift-coding-standards-skill-review.md` 的 P0 清单）**：① 版本表从 v1.3 同步到当前版本（此前只更新了变更记录）；② 8.2 第一批残留的**反向迁移指令**「缩进（4 → 2）、行长（120 → 100）」改为「缩进（每层 4 空格）、行长（120 列）」—— 照旧文执行会把 v1.5 的格式改回去；③ 4.6 续行规则由「缩进 2 空格」改为「相对当前语句缩进一级（+4）」，与 4.5 的每层 +4 一致（实测 swift-format 4 空格配置下的真实输出）。另修正 `naming-antipatterns.md` 中 `drain` 的双向矛盾（词典列为 MUST NOT，而整改手册列在「不改」清单）：`drain` 移出黑名单，依据是 3.1 的「只改读不懂」判据与系统编程通用用法。`remediation-playbook.md` 规则名笔误 `discriminated_optional_boolean` → `discouraged_optional_boolean`；`remediate.sh` 报告里终检命令缺空格 `--strict$DIRS` → `--strict $DIRS`，并在四处把验收标准条数由「7 条」更正为「9 条」 |
| v1.5.2 | 2026-09-11 | **按用户定夺完成三项对齐**：① `identifier_name` 豁免表补入 `i`、`j`（3.5 明文允许的 ≤ 3 行循环计数器），并在 3.5 增补「与工具对齐」说明 —— 此前 `i`/`j` 被误报而规范未提的 `x`/`y`/`z` 等反被豁免；② 5.8 与验收清单的类型体量上限统一为 **300 行**，删除做不到的「500（测试类 300）」承诺 —— 验收要求 `--strict`，warning 即失败，实际一直卡 300（全仓 760 个类型实测最大 295 行，距旧阈值仅 5 行余量）；③ 5.1 增补 force 类规则**分工说明**：强制解包由 SwiftLint `force_unwrapping` 强制、`.swift-format` 的 `NeverForceUnwrap` 显式关闭避免重复报告、`try!` 由 `NeverUseForceTry` 强制。同批新增 `scripts/verify_consistency.sh`（内部一致性自检，期望值从单一权威来源推导，不写第二份硬编码）与 `remediate.sh` 的配置校验门（缺配置 / `included` 作用域为空默认拒绝，防假基线；实测 SwiftLint 的 `included` 相对配置文件所在目录解析，Xcode 工程会静默空扫报 0 违规） |
| v1.5.3 | 2026-09-11 | **按用户定夺完成三项待决修正**：①（C4）`remediate.sh` 的源码目录清单由字符串拼接改为数组 `DIRS_A`，全部命令改用 `"${DIRS_A[@]}"` 展开，消除路径含空格被二次切分的隐患；②（bootstrap）缺配置时不再硬失败，而是**自动从 skill 资产模板生成**缺失的 `.swift-format` / `.swiftlint.yml`（只新增、绝不覆盖已有文件），并把生成的 `.swiftlint.yml` 的 `included` 改写为本次实际检查目录 —— 针对 Xcode 工程无 `Sources/` 的空扫问题；生成失败才退出码 4，`--allow-missing-config` 语义改为「跳过自动生成」；③（D3）**可接受词表收敛到 `naming-antipatterns.md` 第 0 节单一权威**：SKILL.md、本文件 3.1/3.3.6、remediation-playbook.md 的四处词表副本改为引用（`drain` 漂移的根源即多处副本），历史变更记录保留原文不动。同批修正 skill 资产 `swift-format.json` 的 `tabWidth` 残留 8（应为 4，与 4 空格准则一致），并把工程 `.swiftlint.yml` 同步为最新模板（补 `i`/`j` 豁免与 `operator_whitespace` 禁用） |
| v1.5.4 | 2026-09-11 | **复审收尾（docs/skill-review 复审通过后的残余项）**：① SKILL.md `description` 由 667 字压缩至约 260 字 —— description 是每个会话的常驻成本，触发词长清单移入正文「何时使用」维护；「参考文件」补列 `scripts/verify_consistency.sh`；`compatibility` 注明实测版本（SwiftLint 0.63，规则名跨大版本可能漂移）。② `remediate.sh` 采集改为**每阶段缓存原始输出**：`--check` 模式 swift-format / swiftlint 各只跑 1 遍（此前分别 6 遍 / 7 遍），`--fix` 模式因修复后需复采各 2 遍。③ `verify_citations.sh` 新增**反向启发扫描**：正文中 *斜体英文句*（剔除加粗后提取，≥12 字符）逐句到全部快照检索，找不到即失败 —— 堵住「正文新增斜体引文但未登记引文表」这一方向的漂移（此前引文表只能查登记过的引文）；实测当前正文 12 句斜体英文全部有出处，零误报。④ 命名词典第 0 节显式收录 `drain`，使整改手册「词典收录（含 drain）」的表述字面为真（此前 `drain` 只由第 2 节「不在此表内的词默认不动」兜底）。⑤ **修复 macOS 自带 /bin/bash 3.2 的兼容性缺陷**：`set -u` 下变量名后紧跟全角标点时，标点首字节会被并入变量名（`$n，` 报 unbound variable 而 bash ≥ 5 正常）—— remediate.sh 与 verify_consistency.sh 中 14 处该类写法统一改为 `${var}` 花括号形式；实测 verify_consistency.sh 在 /bin/bash 3.2 下跑通全绿 |
| v1.5.5 | 2026-09-11 | **「成员之间空 1 行」从纸面规则变成可机器检出**（起因：用户报「有的函数和函数之间缺少间隔」）。查证发现这条规则此前**三重失效**：① 正文 4.7 早已定为 MUST，但**没有任何工具能查** —— 实测 swift-format 6.3.3 的规则集中没有「成员间空行」项（`maximumBlankLines = 1` 管的是上限即「不许连续两个空行」，不是下限；把两个相邻 `func` 喂给 `swift format`，输出与输入一致），SwiftLint 0.63 同样无对应规则；② 4.0 的表格把「空行位置」整体列入「MUST 之外 → 保留人工排版」，与 4.7 直接矛盾，照哪条读都能自洽，所以这类问题一直没被改；③ 出处没挂全 —— S5 §Vertical Whitespace 的两个除外条款（单行存储属性之间、紧密相关属性之间可空行）在 4.7 里被漏掉，照原文执行会误伤合法的属性分组。**改动**：① 新增 `scripts/verify_member_spacing.sh`（`--check` 只读 / `--fix` 只插空行），把它变成机器可检出；判据是「上一个代码行是独立的一行 `}`、与本声明同缩进、且中间无空行」，按 S5 除外条款**主动跳过**单行存储属性与 enum case，只查**有花括号体的成员**（方法 / 初始化器 / 计算属性 / 嵌套类型，这些在 S5 里没有例外），已知漏检边界如实写在脚本头部。② 正文 4.0 把「空行位置」拆分为「成员之间的分隔空行（MUST）」与「语句组内部是否空行（自由）」，消除矛盾；4.7 补 S5 原文出处、两个除外条款、文档注释的插入位置，并标明这是**唯一一条 swift-format / SwiftLint 都查不出的格式规则**。③ 缺陷全景表新增第 17 类（实测：Sources 374 处 / 49 文件、Tests 329 处 / 42 文件，共 202 + 140 个文件）。④ 顺带修正既有计数脱节：正文原写「表里『能机器检出』的 12 类」，而表里实际只有 11 类标「是」（12 是缺陷目录第 1 节的行数，含表格标为「部分」的第 9 类）—— 改为不写该类数字、只指向缺陷表，不再养第二份副本。⑤ `--fix` 经 202 个文件逐条比对确认**非空行零改动**、且幂等（第二次运行报告 0 个文件被改）；单进程重写后扫描耗时由 45 秒降到 0.7 秒。⑥ `--check` 补为**显式只读别名** —— 此前 SKILL.md 与本节都把只读模式写作 `--check`，但脚本只认「裸目录 / `--quiet` / `--fix`」，照文档敲命令会「未知选项」退出 2；现补上别名使文档与实现一致（纯增补，不改变既有行为），并顺带修掉 `usage()` 的硬编码行号区间（原 `sed -n '2,44p'` 会把 `set -uo pipefail` 与 usage() 定义本身一并打进帮助，改用「打印到首个空行」的动态区间，头部再增删行也不会脱节） |
| v1.5.6 | 2026-09-11 | **补齐「在制品已在树上时如何回退纯格式改动」的流程与一个静默失败陷阱**（起因：真实工程按本规范整改成员空行时，703 处补丁落在已有 325 个在制品文件的树上，规范 8.2 第 1 条只规定了「先提交在制品再重排」这一种顺序，未覆盖顺序已颠倒的补救）。**改动**：`remediation-playbook.md` §2 新增「第 ③ 步的补救」小节 —— 用 `git diff` 把纯格式增量单独存成补丁（存仓库外，勿留 `/tmp`、`/var/folders` 这类会被系统清理的位置）、提交逻辑时 `patch -p1 -R` 撤下再 `patch -p1` 放回、事后用 `--check` 复核；并明确补丁的两条验收（`^+` 行全为空行、`git apply --check -R` 能精确还原）。同节记录一个**实测的静默失败**：仓库根在代码目录上一级时（仓库根 `dock-center-macos`、代码在 `dock-center-macos/UGDockNative`），补丁路径相对代码目录生成而 `git apply` 按仓库根解析，路径对不上只打印 `Skipped patch` 并**返回 0、文件不变**，形似成功 —— 可靠写法为代码目录内 `patch -p1 [-R]`，或仓库根 `git apply [-R] --directory=<代码目录> -p1`，执行后必须用 `git diff --stat` 确认（该陷阱在本次验证中使一次「反向试放成功」的结论失效，故要求以副作用核验而非退出码核验） |
