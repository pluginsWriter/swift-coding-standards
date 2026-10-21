# Swift 生涩命名反模式词典

> 配合 `swift-coding-standards.md` 第 3 章使用，解决 S1 中 `Avoid obscure terms` 那一条的落地问题。
> 所有条目都是**跨工程通用**的 —— 换一个项目，同样的坏味道会以同样的形式出现。

---

## 0. 先明确「不查什么」

命名判据只有一条（正文 3.1）：

> **遮住定义，只看调用点，一个不熟悉本模块的同事能否说出这行在做什么？**

**下列写法明确可以接受，不得以「命名生涩」为由要求重命名**：

`normalize`、`reserve`、`blockWrites`、`u16`、`perform`、`flight`、`generation`、`resolve`、`process`、`validate`、`snapshot`、`drain`、`cfg`、`msg`、`req`/`resp`、`ctx`。

这些是中文开发者普遍熟悉的常用词与高频缩写，含义在上下文中是确定的。把它们当缺陷只会制造无意义的重命名与 diff 噪音。**规范的成本必须换来看得见的收益。**

只有出现下面三种情况才需要改名：

1. **生僻词** —— 读者要先查词典（`reify`、`thunk`、`amortize`）；
2. **自造缩写与单字母** —— 只有作者或本团队能还原（`aniDur`、`l`、`r`、`w`）；
3. **对象或返回值无从判断** —— 重名、语序错乱、词性错。

---

## 1. 必须改的反模式

### A. 生僻词与借喻黑话（MUST NOT）

词在母领域有确切含义，借过来后语义漂移，读者必须先「学会黑话」才能读代码。

| 禁止 | 问题 | 改为 |
| --- | --- | --- |
| `reify` | 生僻哲学词 | 描述实际动作：`materialize` / 具体的领域动词 |
| `thunk` | 编译器术语，借来指「延迟执行的包装」 | `deferredValue`、`lazyWrapper` |
| `amortize` | 会计术语，读者要查词典 | `spreadOverTime`、`distributeEvenly` |
| `hydrate` | 含水隐喻 | `populate`、`fill` |
| `saga` | 分布式术语，滥用后无意义 | `coordinationSequence` |
| `probe` | 无明确语义 | `healthCheck` |
| `budget`（表「上限」） | 预算 ≠ 上限 | `maximumBytes`、`limit` |

**判定规则**：这个词在项目内**没有正式定义**，又不属于 Swift / 系统 API 的既有术语，就禁止使用。

### B. 名词 / 形容词当动词（MUST NOT）

读者无法区分「这是查询还是动作」。

| 禁止 | 词性 | 改为 |
| --- | --- | --- |
| `stored(_:)` | 过去分词 | `storedConfiguration(for:)` |
| `previews(_:apps:)` | 名词 | `makePreviews(configuration:apps:)` |
| `services(className:)` | 名词 | `findServices(className:)` |
| `properties(_:)` | 名词 | `registryProperties(of:)` |
| `registryID(_:)` | 名词 | `registryID(of:)` |
| `validID(_:)` | 形容词 | `isValidDisplayID(_:)` |
| `matchedUSBAncestor(_:ids:)` | 过去分词 | `matchingUSBAncestorID(of:in:)` |

**判定规则**：布尔返回值的函数用 `is` / `has` / `can` / `should` 开头；其余动作用祈使动词。

### C. 自造缩写与单字母（MUST NOT）

**自造**的定义：只有作者或本团队能还原。行业既定的高频缩写不在此列（见第 0 节）。

| 禁止 | 改为 |
| --- | --- |
| `aniDur` | `animationDuration` |
| `srtAnmating` | `startAnimating` |
| `vc` / `btn` | `viewController` / `button` |
| `l`、`r` | `left`、`right` |
| `w`、`h` | `width`、`height` |
| `n` | `count` / `value`（视语义） |
| `c`、`p`、`d`、`g` | 展开为完整词 |
| `i`、`j` | **仅在作用域 ≤ 3 行的循环计数器**时可用 |

**可以保留**：`URL`、`ID`、`USB`、`HID`、`HTTP`、`JSON`、`UUID`、`API`、`CPU`、`ABI`，以及 `cfg` / `msg` / `req` / `ctx` / `u16` 这类含义固定的高频写法。

### D. 缺失量纲与单位（MUST NOT）

数值型名字不写单位，是跨端协作中最高频的缺陷来源。

| 禁止 | 改为 | 理由 |
| --- | --- | --- |
| `timeout` | `timeoutMilliseconds` / `timeoutSeconds` | 毫秒还是秒？ |
| `size` | `byteCount` / `pixelSize` | 字节还是像素？ |
| `length` | `byteCount` / `characterCount` | 长度单位 |
| `rate` | `refreshRateHertz` | 频率单位 |
| `delay` | `retryDelaySeconds` | 时间单位 |

**判定规则**：凡是数值参数，名字里必须出现单位或量纲；`Int` / `Double` / `TimeInterval` 一律适用。

### E. 二义性与状态阶段混淆（MUST NOT）

| 问题词 | 歧义 | 改为 |
| --- | --- | --- |
| `block` | 阻塞，还是阻止？ | 阻塞用 `wait`；阻止用 `disable` / `disallow` |
| `close` vs `requestClose` | 同步关闭 vs 请求关闭 | `close()`（完成后返回）／`scheduleClose()`（异步请求） |
| `waitForClosing()` | 介词结构不当 | `waitUntilClosed()` |
| `beginX` / `finishX` / `didX` 混用 | 分别表示「开始」「完成」「回调」 | `beginXing()` / `finishXingIfReady()` / `handleDidX()` |
| `sync` | 动词还是名词？ | 动作用 `synchronize`，`sync` 只作名词或属性 |

**判定规则**：`did` 前缀只用于**系统回调**语义；`begin` / `finish` 用于**本对象主动推进的阶段**；两者不得混用。

### F. 前后缀滥用（MUST NOT）

| 禁止 | 原因 | 改为 |
| --- | --- | --- |
| `getXxx()` | 与属性语法重复，社区通行约定禁止 | 属性 `xxx`，或去掉 `get` |
| `createXxx()` / `buildXxx()` | S1 要求工厂用 `make` | `makeXxx()` |
| `withXxx(...)` | S1 明确不推荐 | `makeXxx(...)` / `configured(with:)` |
| `xxxProtocol` | 协议名禁忌 | 直接去掉后缀 |
| `xxxImpl` | 实现细节不该进类型名 | 用具体实现特征命名，如 `KeychainSecureStore` |

### G. 集合单复数（MUST）

- 复数名字必须是真集合：`devices`、`records`、`ids`。
- 集合的**数量**用 `count`，不要用复数名表示数量。
- 禁止 `list`、`array`、`dict` 出现在名字里（`deviceList` → `devices`）。

### H. 可选与布尔（MUST）

- 布尔禁止 `flag` / `state` 等无信息后缀：`cancelledFlag` → `isCancelled`。
- 禁止 `Bool?`：`isEnabled: Bool?` → `enum Availability { case enabled, disabled, unknown }`。
- 禁止否定式布尔：`isNotEmpty` → `isEmpty`。
- 布尔属性读作对接收者的断言（S1）：`buffer.isEmpty`、`line1.intersects(line2)`。

### I. 名称过长（MUST NOT）

**超过 50 个字符即为违规**。过长几乎总是说明「这个类型该拆了」，而不是「需要更长的名字」。

```swift
// 不好：55 字符，调用点无法解析
let configurationPersistenceApplicationSupportNotAbsoluteFileURL = ...
// 好：先拆类型，再起短名
enum ConfigurationError { case persistencePathNotAbsolute }
```

---

## 2. 快速替换对照表

| 你在写 | 类别 | 替换方向 |
| --- | --- | --- |
| `reify` / `thunk` / `amortize` / `hydrate` / `saga` | A 生僻词 | 换成描述动作的常用词 |
| `probe` / `budget` | A 借喻 | `healthCheck` / `maximumBytes` |
| `stored` / `previews` / `selected` / `validX` | B 词性错 | `storedXxx(for:)` / `makeXxxs` / `isValidXxx` |
| `services` / `properties` / `registryID` | B 词性错 | `findServices` / `registryProperties(of:)` |
| `aniDur` / `srtAnmating` / `vc` / `btn` | C 自造缩写 | 展开 |
| `l` / `r` / `w` / `h` / `n` / `c` / `p` / `d` | C 单字母 | 展开 |
| `timeout` / `size` / `length` / `delay` | D 缺单位 | 加单位后缀 |
| `block` | E 歧义 | `wait`（阻塞）或 `disable`（阻止） |
| `requestClose` / `waitForClosing` | E 阶段混淆 | `scheduleClose` / `waitUntilClosed` |
| `getXxx` | F 前后缀 | 去掉 `get` |
| `createXxx` / `buildXxx` / `withXxx` | F 前后缀 | `makeXxx` |
| `xxxProtocol` / `xxxImpl` | F 前后缀 | 去掉 |
| `deviceList` / `recordArray` | G 集合 | `devices` / `records` |
| `cancelledFlag` / `isNotEmpty` | H 布尔 | `isCancelled` / `isEmpty` |
| 超过 50 字符的长名 | I 过长 | 拆类型 |

**不在此表内的词，默认不动。** `normalize`、`perform`、`resolve`、`flight`、`generation`、`u16` 等都在此列。`drain`（排空队列 / 迭代器）原属借喻类，2026-09-11 移入「默认不动」—— 它是系统编程的通用动词（IOKit 迭代器、通道、队列），且调用点配合上下文可读，符合「只改读不懂」的判据。

---

## 3. 自检方法

改完名字后逐条过一遍：

1. **调用点测试**：把定义遮住，只看调用行，能说出在做什么吗？
2. **还原测试**：这个名字除了作者，别人能还原出它代表什么吗？（测的是自造缩写）
3. **词性测试**：函数名是祈使动词（动作）或 `is/has/can`（查询）吗？
4. **单位测试**：每个数值参数的名字里有单位吗？
5. **长度测试**：超过 50 个字符了吗？如果是，先考虑拆类型。

**五条里任何一条不过，就还没有到可以提交的程度。**

> 注意：本词典只用于**主动命名的场景**与**新增代码的评审**。对存量代码，只有上述第 1、2、3 节（MUST 级）才进入整改范围；第 0 节列出的可接受词一律不要动。
