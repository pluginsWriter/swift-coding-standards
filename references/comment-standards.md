# Swift 注释与文档规范

> 本文是 `swift-coding-standards.md` 5.7 的展开，可独立查阅。
> **来源**：整合自团队成员提供的《Swift 编码注释规范》，已与 S1（Swift API Design Guidelines）、S3（swift-format）对齐，并去掉了与正文重复的部分。

**核心原则**：文档注释说明**调用契约**，实现注释说明**设计原因**；能由类型、命名和代码结构表达清楚的信息，不再重复写进注释。

**约束强度**：**必须**（不得违反）／**应该**（默认遵循，有明确工程原因可例外）／**可以**（按需选择）。

---

## 1. 文档注释 `///`

### 1.1 使用范围

| 对象 | 要求 |
| --- | --- |
| `public` / `open` API、公开协议要求 | **必须**（S1 明文；SwiftLint `missing_docs`） |
| 行为、边界条件或副作用不直观的内部接口 | 应该 |
| 复杂初始化器、异步操作、可能抛错的方法 | 应该 |
| 含义从名称与类型可直接看出的简单 `private` 成员 | 可以省略 |

**不要为了覆盖率给每个私有变量、简单 getter 或直观辅助方法加注释。** 无信息增益的注释是负债。

### 1.2 内容结构

按以下顺序组织：

1. 第一段：一句话概述行为或用途（不超过一行）。
2. 需要时补充详细说明，**与摘要之间留一个空注释行**。
3. 参数 → 返回值 → 抛出条件。
4. 最后是注意事项、复杂度或重要约束。

```swift
/// Loads the current state of a connected device.
///
/// This method returns cached data when the provider is temporarily
/// unavailable.
///
/// - Parameters:
///   - identifier: The stable identifier of the device.
///   - cachePolicy: How long a cached value may be reused.
/// - Returns: The latest known device state.
/// - Throws: `DeviceError.notFound` when the device is unavailable.
func loadState(
    for identifier: DeviceIdentifier,
    cachePolicy: CachePolicy
) async throws -> DeviceState
```

**单个参数用 `- Parameter x:`，两个及以上用复数 `- Parameters:`。** 中文项目写中文说明，但标识符、类型名、技术术语保持英文原文。

### 1.3 DocC 标记

```swift
/// - Parameter value: The value to process.
/// - Returns: The processed value.
/// - Throws: An error when validation fails.
/// - Note: Additional information for normal usage.
/// - Important: A condition callers must understand.
/// - Warning: A behavior that may cause data loss or incorrect results.
/// - Complexity: O(n), where n is the number of elements.
```

- 标识符、类型名、代码片段用反引号：`` `DeviceState` ``。
- **禁止 JavaDoc / Doxygen 风格**的 `@param`、`@return`。
- **只用 `///`，禁止块注释 `/** */`** —— S3 的 `UseTripleSlashForDocumentationComments` 要求 `///`，`NoBlockComments` 禁止块注释。
  > 注：S6（LinkedIn 指南 4.1.2）要求用 `/** */`，与本条冲突，**以 S1/S3 为准**（见正文 1.3 冲突表）。

### 1.4 参数与返回值要写全

如果决定写参数文档，就要写全（缺一个会让 Xcode 快速帮助看起来是坏的）；只有一个参数值得说明时，把它写进描述段落即可，不要只列一个 `- Parameter`。

---

## 2. 实现注释 `//`

实现注释只写**代码本身表达不了**的信息：

- 采用当前实现的原因与技术权衡；
- 业务规则、系统限制、兼容性约束；
- 不明显的边界条件、算法不变量、生命周期要求；
- 并发、线程、缓存与资源所有权的假设。

```swift
// 推荐：解释为什么
// Keep provider access outside MainActor because HID reads may block.
let state = await provider.readState()

// 不推荐：复述代码
// Read the state.
let state = await provider.readState()
// Increase the retry count by one.
retryCount += 1
```

**禁止长期保留被注释掉的旧代码。** 历史实现由版本控制系统保存。

---

## 3. 文件结构标记 `// MARK:`

```swift
// MARK: - Lifecycle

// MARK: - Public API

// MARK: - Delegate

// MARK: - Private Helpers
```

- `// MARK: -` 用于建立带分隔线的主要区域，`// MARK:` 后的**下一行必须留空行**。
- 仅在确实有助于导航时使用；**不要为每个属性或方法单独建一个 `MARK`**。
- 较大的类型或文件、以及用扩展分组实现协议时，都应加 `MARK`。

---

## 4. TODO 与 FIXME

```swift
// TODO: [DEV-142] Replace polling after the provider supports events.
// FIXME: Cancellation can leave the connection in a reconnecting state.
```

- `TODO` —— 尚未实现但已计划处理的工作。
- `FIXME` —— 已知错误、不正确行为或临时方案。
- **应该**包含原因，并尽量关联 issue 编号、负责人或完成条件。
- 本次改动新增的 `TODO` / `FIXME` **必须**在交付说明中明确指出，不能悄悄留下。

---

## 5. 并发注释

优先通过 `actor`、`@MainActor`、`Sendable` 和类型系统表达并发约束；**只有编译器无法验证的约束才写进注释**。

需要补充说明的情形：

- actor 重入可能影响状态一致性；
- cancellation 会留下部分完成的状态，或需要清理资源；
- 回调存在特定的顺序、执行器或队列要求；
- 使用了 `@unchecked Sendable`、锁或 `nonisolated(unsafe)` 等逃逸机制（**这类注释是强制的**，见正文 5.5）；
- 存在必须遵循的锁顺序、缓存一致性或对象生命周期规则。

```swift
// Capture the generation before suspension. Actor reentrancy may replace
// the active connection while the network request is running.
let generation = connectionGeneration
let response = try await client.send(request)
guard generation == connectionGeneration else { return }
```

---

## 6. 语言与格式

- **同一项目内注释语言必须一致。** 对外 SDK、开源项目、跨地区团队通常用英文；内部中文团队可用中文，但 API、类型与技术术语保持英文原文。
- 文档段落用完整、清晰的句子；**摘要保持简短**（一句话）。
- **`//` 与 `///` 之后必须有一个空格。**
- **注释独占一行**，不得写在代码行尾后紧跟多个语句（行尾注释仅允许用于简短标注，且与代码之间空 2 个空格）。
- 行长遵循正文 4.6：单行不超过 120 列，不在本文单独规定另一套上限。

---

## 7. 维护要求

- 修改行为时**同步检查相邻的文档注释与实现注释** —— 过期注释比没有注释更有害。
- 删除已失效、与代码矛盾或没有信息增益的注释。
- **注释不得承诺实现没有保证的线程安全、性能或错误恢复能力。**
- 能通过更准确的命名、类型或函数拆分消除注释时，**优先改进代码表达**而不是补注释。

---

## 8. Code Review 检查清单

- [ ] 公开 API 与重要内部接口是否说明了调用契约？
- [ ] 参数、返回值、抛出条件以及异步取消行为是否准确？
- [ ] 实现注释是否解释了**原因**，而不是复述代码？
- [ ] `TODO` / `FIXME` 与并发假设是否可以追踪、且仍然有效？
- [ ] `@unchecked Sendable` 等逃逸机制是否有说明可变性来源的注释？
- [ ] 本次修改是否产生了过期注释或被注释掉的代码？
- [ ] 是否用 `/** */` 块注释（应改为 `///`）？

---

## 9. 参考

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) —— 命名与文档注释的权威依据（本地快照：`references/official/s1-api-design-guidelines.md`）
- [Swift DocC: Formatting Your Documentation Content](https://www.swift.org/documentation/docc/formatting-your-documentation-content)
- [Apple Markup Formatting Reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_markup_formatting_ref/)

> 以上链接用于需要时回查；本文件自身不联网，规则已内联。
