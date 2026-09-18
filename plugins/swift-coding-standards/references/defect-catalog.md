# 缺陷目录与检测方法

> 配合 `swift-coding-standards.md` 第 0 章使用。第 0 章给结论，本文给**怎么查**与**怎么改**。
> 所有命令在 macOS 默认 shell（zsh / BSD 工具链）下可直接运行。

## 0. 使用方式

```bash
# 一次性拿到全部类别的数量（推荐，已内置去重与 stderr 处理）
bash <skill-dir>/scripts/remediate.sh <工程目录> --check

# 或按下面的单条命令逐类排查
```

**两条必须牢记的计数陷阱**（正文 8.1）：

- `swift format lint` 的违规输出走 **stderr**，用 `2>/dev/null` 会得到「零违规」的假结论；
- 它会**重复输出**同一条违规约 3.5 倍，必须先按 `文件:行:列:规则` 去重。

---

## 1. 机器可检出（交给工具，不靠人自觉）

| # | 类别 | 检测命令 | 整改动作 |
| - | --- | --- | --- |
| 3 | 一行多语句 / 多 `case` / 多变量声明 | `swift format lint --recursive Sources 2>&1 \| grep -E 'DoNotUseSemicolons\|OneCasePerLine\|OneVariableDeclarationPerLine'` | `swift format --in-place` 可全自动修 |
| 4 | 花括号未换行 | 同上，规则 `AddLines` | 同上 |
| 5 | 公开 API 无文档 | `swiftlint lint --quiet 2>&1 \| grep missing_docs` | 按 `comment-standards.md` 补 `///` |
| 6 | 强制解包族 | `swiftlint lint --quiet 2>&1 \| grep -E 'force_unwrapping\|force_try\|force_cast\|implicitly_unwrapped_optional'` | `!`/`try!`/`as!` → `guard let` / `do-catch` / `as?`；测试用 `XCTUnwrap` |
| 7 | 类型与函数过大 | `swiftlint lint --quiet 2>&1 \| grep -E 'function_body_length\|type_body_length'` | 见正文 5.8 处理顺序 |
| 8 | 复杂度过高 | `swiftlint lint --quiet 2>&1 \| grep cyclomatic_complexity` | 查表/状态枚举替换分支链 |
| 9 | 大元组 | `swiftlint lint --quiet 2>&1 \| grep large_tuple` | 改具名 `struct` |
| 11 | 可选值误用 | `swiftlint lint --quiet 2>&1 \| grep -E 'discouraged_optional_boolean\|implicit_optional_initialization'` | `Bool?` → 状态枚举；删掉 `= nil` |
| 12 | 修饰符顺序 | `swiftlint lint --quiet 2>&1 \| grep -E 'modifier_order\|attributes'` | 按配置顺序重排 |
| 13 | 冗余代码 | `swiftlint lint --quiet 2>&1 \| grep unneeded_synthesized_initializer` | 删掉手写 init |
| 15 | 测试断言过弱 | `swiftlint lint --quiet 2>&1 \| grep -E 'xctfail_message\|xct_specific_matcher'` | 补失败说明；改用专用断言 |
| 16 | 行长失控 | `swiftlint lint --quiet 2>&1 \| grep line_length` | 先提取中间变量，再断行 |
| 17 | 成员间缺分隔空行 | `bash <skill-dir>/scripts/verify_member_spacing.sh <目录>...`（**swift-format 与 SwiftLint 都没有这条规则**，只能用它） | `--fix` 插入空行；注意 S5 除外条款：单行存储属性之间、单行 enum case 之间、紧密相关的两个属性之间**可以**不留空行，不要误改 |

## 2. 需要判断，但可用 grep 定量（部分可检出）

| # | 类别 | 检测命令 | 整改动作 |
| - | --- | --- | --- |
| 1 | 单字母 / 过短命名 | `swiftlint lint --quiet 2>&1 \| grep identifier_name` | 展开为完整词（`l`→`left`） |
| 2 | 过长命名 | 同上（同一规则的上限侧） | 先拆类型，再起短名 |
| 1 | 自造缩写 | `grep -rnE '\b(aniDur\|srtAnmating\|cfg\|msg\|req)\b' Sources --include='*.swift'` | 判断是「高频缩写」还是「自造缩写」：后者展开 |
| 9 | 关联值未具名 | `grep -rnE 'case [A-Za-z_][A-Za-z0-9_]*\(' Sources --include='*.swift' \| grep -E '\([^)]*(String\|Int\|Double\|Bool)'` | 补参数标签 |
| 14 | 并发逃逸未说明 | `grep -rn '@unchecked Sendable' Sources --include='*.swift'` | 逐个补注释说明可变性来源 |
| — | 确定性风险 | `grep -rn 'Task.sleep' Sources --include='*.swift'` | 确认是否用于轮询；是则改 `AsyncStream` / actor 状态 |

## 3. 纯人工评审（机器查不出，只能靠规则与评审）

| # | 类别 | 现象 | 判断依据 |
| - | --- | --- | --- |
| 10 | 魔法字符串 | 同一字段名 `"display_id"` 在映射、校验、序列化处各写一遍 | **同一字面量出现 ≥ 2 次即为违规**（正文 5.9） |
| 10 | 模式字符串当枚举用 | `["fill","fit","stretch"].contains(mode)` | 应定义 `enum: String` 并用 `init(rawValue:)` |
| — | 万能字典代替类型 | `[String: JSONValue]` 在模块间传递结构化数据 | 模块边界应用具名类型，字面量只留在序列化层 |
| — | 死代码 | 被注释掉的旧实现 | 直接删除，历史交给版本控制 |
| — | 过期注释 | 注释与代码矛盾、承诺未实现的保证 | 改代码时同步检查相邻注释 |
| — | 无跟踪的 TODO | `TODO:` 后面没有原因、issue 或负责人 | 补全，或在交付说明中列出 |
| — | 错误信封泄漏 | 模块边界抛出 `NSError` / `errno` / `io_return` | 转成项目自定义错误类型（正文 5.4） |

---

## 4. 按类别的实测样本（来自 UGDockNative，188 文件 / 17K 行）

这些是**真实检出**的样本，可作为「什么算违规」的对照。整改时不要照抄结论，要按当前代码重新判断。

| 类别 | 样本 |
| --- | --- |
| 一行多语句 | `BridgeDisplayMapper.swift:41`：`guard params.isEmpty else { throw ... }; return .snapshot` |
| 一行多 `case` | `DisplayFeature.swift:20`：`case fill, fit, stretch` |
| 无标签关联值 | `BridgeDisplayMapper.swift:25`：`case wallpaper([String], String, String)` |
| 大元组 | `IOKitUSBDeviceSource.swift:100`、`BridgePeripheralMapper.swift:27` |
| 魔法字符串 | `BridgeDisplayMapper.swift` 一个文件内 `"display_id"` / `"changes"` 等键重复出现多次 |
| 魔法模式串 | `DisplayPreferences.swift:73` 与 `BridgeDisplayMapper.swift:66` 各自硬编码 `["fit","fill","stretch"]` |
| 强制解包 | `ApplicationSettingsCoordinator.swift:90`：`targets[entry.owner.scope]!`（字典下标 + 强制解包） |
| `try!` | `SettingsBackup.swift:39`：`try! .init(value: ...)`（error 级） |
| 复杂度 47 | `HIDReportDescriptorLayout.swift:46`（上限 15） |
| 函数 130 行 | `DefaultCoreRuntimeBuilder.swift:66` |
| 类型 608 行 | `UGApplicationRuntime.swift:21`（actor body） |
| 过长命名 | `CoreErrorCodeValues.swift:13`：55 字符常量名 |
| 并发逃逸 | 12 处 `@unchecked Sendable`，分布在 `UGHardware` 与 `UGDockNativeBridge` |
| 成员间缺分隔空行 | `UGDisplay/CoreGraphicsDisplayAdapter.swift:230`：`private func resolve` 紧贴上一个函数的 `}`；同类共 Sources 374 处 / 49 文件、Tests 329 处 / 42 文件（2026-09-11 重扫） |

---

## 5. 建议的排查顺序

1. **先跑工具**（第 1 节）—— 这部分不需要讨论，直接修。
2. **再扫可定量项**（第 2 节）—— 逐条判断，批量改。
3. **最后人工评审**（第 3 节）—— 这类改动影响面最大，必须走评审与回归。

> 第 3 节的三类（魔法值、万能字典、错误信封）是最容易被工具漏掉、又最容易在线上出问题的一类：它们不会让 lint 报错，但会让下一次协议变更变成一场搜索。
