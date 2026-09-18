# 完整整改手册（Remediation Playbook）

用户显式要求「把代码改规范」时用本手册执行。

**本手册存在的意义：防止只跑一次格式化就宣称整改完成。** 格式化只解决格式，命名、文档、数据建模、魔法值不会被它碰到，而后者往往才是用户抱怨的重点。

---

## 1. 「完整」的验收标准

以下 9 条**全部满足**才算整改完成。任何一条不满足都必须继续，并在报告中如实说明剩余项。

> 验证命令里的 `$SKILL` / `$PROJ` / `$DIRS` 三个变量约定见 `SKILL.md`「路径与变量约定」。
> 不要用尖括号包裹的占位符 —— zsh 会把 `<` 当成输入重定向，照抄直接报 `parse error`。

| # | 验收标准 | 验证方式 |
| --- | --- | --- |
| 1 | 格式零违规 | `swift format lint --recursive --strict $DIRS` 无输出，**且** `bash "$SKILL/scripts/verify_member_spacing.sh" $DIRS --quiet` 报 0 处（成员间空行不在 swift-format 的规则集里，前者查不出） |
| 2 | 语义零违规 | `swiftlint lint --strict --quiet` 无输出 |
| 3 | 命名只剩「可接受项」 | 无单字母、无自造缩写与生僻词、无超长名；**保留的常用词需在报告中列出理由** |
| 4 | 无强制解包类缺陷 | 无 `force_unwrapping` / `force_try` / `force_cast` / 隐式解包可选 / `unowned` |
| 5 | 公开 API 有文档 | 无 `missing_docs`，且 `Throws` 条件已写明（规范 5.7 + `comment-standards.md`） |
| 6 | 数值参数带量纲 | 名称含单位（`timeoutMilliseconds`、`byteCount`） |
| 7 | 无魔法字符串与数值 | 同一字面量出现 ≥ 2 次处均已提取具名常量（规范 5.9） |
| 8 | 数据建模合规 | 关联值具名；无 3 成员以上元组；协议字段走具名类型 |
| 9 | 提交已拆分 | 格式 / 语义 / 重命名三类改动不在同一提交 |

> 第 2 条要用 `--strict`：默认模式下 warning 不算失败，会被漏过。

**关于第 3 条 —— 最容易做错的一条。** 命名整改的判据是**调用点能不能读懂**，不是「`identifier_name` 数字归零」。`SwiftLint` 的该规则会同时报「过短」和「过长」两种相反的问题，必须人工筛选：

- **要改**：单字母（`l`/`r`/`w`）、自造缩写（`aniDur`）、生僻词（`reify`/`thunk`）、超过 50 字符的长名、名词/形容词当动词。
- **不要改**：`naming-antipatterns.md` 第 0 节词典收录的全部可接受词（权威词表，本文件不复制；含 `drain`）—— 中文开发者普遍熟悉的常用词与高频缩写，改名只会制造 diff 噪音（规范 3.1）。

**允许的例外**：确有理由无法满足时（例如 C ABI 固定符号名、测试夹具故意保留），必须在报告中逐条列出并说明理由。**「改起来太麻烦」不是理由，「这个词不眼熟」也不是。**

---

## 2. 整改顺序（不要打乱）

```
① 冻结功能改动  →  ② 确认排版策略  →  ③ 机械修复  →  ④ 复检并记录
                                        ↓
        ⑦ 终检与报告  ←  ⑥ 数据建模与魔法值  ←  ⑤ 语义修复与命名整改
```

顺序理由：

- **必须先冻结功能改动**，否则格式 diff 会淹没逻辑改动，review 无法进行（规范 8.3）。
- **先确认排版策略**（见下），它决定第三步动的是「全部格式」还是「仅四类必改项」。
- **机械修复必须在手写修改之前**：先让工具改完，人工改动量会大幅下降。
- **重命名放最后**：重命名会产生大面积 diff，放在格式稳定之后做，diff 才干净可审。
- **public API 重命名单独成批**：影响调用方，需先写 ADR（规范 8.2 第四批）。

### 第 ② 步：确认排版策略（规范 4.0）

格式有两个合法来源：工具排版与人工排版。**先问清楚要哪一种，再动手** —— 这是整份手册里唯一需要用户决策的地方。

| 策略 | 做法 | 适用 |
| --- | --- | --- |
| A. 接受工具排版 | `swift format --in-place --recursive Sources Tests` 全量重排 | 团队没有手写排版习惯，或希望彻底统一 |
| B. 保留人工排版 | 只跑 `swift format lint` 出报告，**仅修四类必改项**，其余手写排版不动 | 代码中有刻意的对齐、分组断行 |

无论哪种策略，四类必改项都必须修：**分号、块内多语句压行、`defer{`、关键字与花括号之间缺空格**。需要长期豁免的个别位置加 `// swift-format-ignore`。

> **还有一类不在这四类里，但漏了它就是假达标**：成员之间缺分隔空行（规范 4.7，缺陷目录第 17 类）。**swift-format 与 SwiftLint 都没有这条规则**，`swift format lint` 永远不报，只能用 `bash "$SKILL/scripts/verify_member_spacing.sh" $DIRS` 检出（`--fix` 可插空行）。「格式零违规」的结论必须包含这一条的数字。

### 第 ③ 步的补救：机械修复已经跑过、而树上有在制品（规范 8.2 第 1 条）

规范 8.2 第 1 条要求「存在未提交的在制品 → 先把在制品单独提交，再执行重排」。**顺序反过来时**（在制品早已在树上、机械修复已经跑完）不要 `git add -A` 一把提交 —— 那正是「格式与逻辑混进同一个提交」的现场。用补丁把两者拆开：

1. **立刻**把这次纯格式增量单独存成补丁，并**存到仓库外**（`/tmp`、`/var/folders` 会被系统清理）：

   ```bash
   CHANGED_FILES="Sources/HomeView.swift Sources/HomeStore.swift"   # 换成本次被格式工具改动的文件
   PATCH_DIR=/path/to/outside-repo                                  # 必须落在仓库外
   git diff -- $CHANGED_FILES > "$PATCH_DIR/format.patch"
   ```

   验收两条：补丁里 `^+` 开头的行应**全部为空行**（非空新增为 0）；`git apply --check -R` 能精确还原当前工作区。
2. 要提交在制品逻辑改动时走三步：`patch -p1 -R < "$PATCH_DIR/format.patch"`（先撤掉格式）→ 提交逻辑 → `patch -p1 < "$PATCH_DIR/format.patch"`（再放回格式）→ 单独提交格式。
3. 事后复核：`bash "$SKILL/scripts/verify_member_spacing.sh" $DIRS --check` 应为 0 处，确认格式增量仍在。

⚠️ **`git apply` 有静默跳过陷阱**（已实测）：当仓库根在代码目录的**上一级**（例：仓库根 `dock-center-macos`、代码在 `dock-center-macos/UGDockNative`），补丁路径通常是相对代码目录生成的，而 `git apply` 按**仓库根**解析路径 —— 路径对不上时它只打印 `Skipped patch`，**返回 0 且文件纹丝不动**，看起来像成功。可靠写法只有两种：在代码目录用 `patch -p1 [-R]`；或从仓库根用 `git apply [-R] --directory=CODE_DIR -p1`（`CODE_DIR` = 代码目录相对仓库根的路径）。执行后**必须**用 `git diff --stat` 或文件字节数确认真的生效。

---

## 3. 逐类整改动作

### ③ 机械修复

```bash
# 策略 A（接受覆盖）：一次性重排
swift format --in-place --recursive Sources Tests

# 策略 B（保留人工排版）：只报告，人工只改四类必改项
swift format lint --recursive Sources Tests 2>&1 | grep -E 'DoNotUseSemicolons|AddLines'

# 两种策略都要跑 —— swift-format 查不出的「成员间缺空行」
bash "$SKILL/scripts/verify_member_spacing.sh" $DIRS
```

`swiftlint lint --fix` 在本规范配置下作用有限（格式规则已禁用），可跑但不要指望它。

产物：**每个 Target 一个提交**，信息统一 `style: apply swift-format to TARGET_NAME`（把 `TARGET_NAME` 换成实际 Target 名）。

> 策略 A 下不要手工再改格式；策略 B 下不要跑 `--in-place` —— 两种做法混用会来回覆盖。

### ④ 复检并记录前后基线

```bash
swift format lint --recursive $DIRS 2>&1 | grep -E '\[[A-Za-z]+\]' | sort -u \
  | grep -oE '\[[A-Za-z]+\]' | sort | uniq -c | sort -rn
swiftlint lint --quiet 2>&1 | grep -oE '\([a-z_]+\)$' | sort | uniq -c | sort -rn
```

注意 `2>&1`（输出走 stderr）和 `sort -u`（会重复输出约 3.5 倍），漏一个数字就错。

把「修复前 / 修复后」两列数字写进报告。**没有前后对比就无法证明整改有效。**

### ⑤ 语义修复与命名整改

按规则处理，逐条对照：

| 规则 | 整改动作 |
| --- | --- |
| `force_unwrapping` | 改 `guard let` / `if let`；确实不可能的用 `preconditionFailure` + 注释说明不变式 |
| `force_try` / `force_cast` | 改为 `do/catch` / `as?`；测试中改用 `XCTUnwrap` |
| `implicitly_unwrapped_optional` | 除 `@IBOutlet` 外一律改普通可选或非可选 |
| `missing_docs` | 补 `///`：摘要 → 参数 → 返回值 → Throws（`comment-standards.md`） |
| `large_tuple` | 提取为具名 `struct`，字段名即文档 |
| 无标签关联值 | 补参数标签（`case wallpaper(displayIDs:filePath:mode:)`） |
| `function_body_length` / `type_body_length` | 按职责拆分；拆分边界写进提交信息 |
| `cyclomatic_complexity` | 用查表 / 状态枚举替换分支链，禁止靠注释规避 |
| `discouraged_optional_boolean` / `implicit_optional_initialization` | 改状态枚举 / 删掉 `= nil` |
| `modifier_order` | 按配置顺序重排（`nonisolated` 在访问修饰符之前） |
| `line_length` | 由 swift-format 断行；若断行后仍超限，说明表达式本身过长，应提取中间变量 |
| `xctfail_message` / `xct_specific_matcher` | 补断言失败说明；改用专用断言 |

**命名（按规范 3.1 的三类判据）**：

| 类别 | 处置 |
| --- | --- |
| 单字母标识符（`l`/`r`/`w`/`h`/`n`/`c`/`p`/`g`） | **改** —— 展开为完整词 |
| 自造缩写（`aniDur`、`srtAnmating`、`vc`、`btn`） | **改** —— 展开 |
| 生僻词（`reify`、`thunk`、`amortize`、`hydrate`、`saga`） | **改** —— 换成描述动作的常用词 |
| 超过 50 字符的长名 | **改** —— 先拆类型，再起短名 |
| 名词 / 形容词当动词（`stored`、`previews`、`services`、`validID`） | **改** —— 恢复正确词性 |
| 前后缀滥用（`withXxx`、`createXxx`、`buildXxx`、`getXxx`） | **改** —— 工厂用 `make`，属性不加 `get` |
| 缺量纲的数值名（`timeout`、`size`、`length`） | **改** —— 补单位 |
| 歧义词（同一作用域内多个语义不同的 `release` / `cancel` / `resolve`） | **改** —— 补宾语区分 |
| 词典收录的可接受词（唯一权威：`naming-antipatterns.md` 第 0 节） | **不改** —— 常用词与高频缩写，报告里列出来即可 |

**判定标准（最容易执行的一条）**：遮住定义，只看调用点 —— 一个不熟悉本模块的人能否读懂这行在做什么？不能就必须改。

**两类命名要区别对待**：

- `private` / `internal` 成员：可直接改，改完跑受影响测试即可。
- `public` API：**先写 ADR**，再改，然后对受影响测试完整回归。跨语言边界（C ABI、Bridge 导出符号）尤其如此。

> **需要 `swiftlint analyze` 的规则不会出现在 `lint` 结果里**，例如 `unused_import`、`unused_declaration`。
> 这类规则依赖编译器索引，必须单独跑：
>
> ```bash
> swiftlint analyze --compiler-log-path /path/to/build.log --quiet
> ```
>
> 无法提供编译日志时需人工扫一眼 import 是否都有使用。**不要因为没有输出就认为这几类已达标。**

### ⑥ 数据建模与魔法值（v1.3 新增的整改面）

这一步容易被完全跳过，因为它**不会让任何工具报错**，但恰恰是后续改动最容易出错的地方。

| 检查项 | 动作 |
| --- | --- |
| 同一字符串字面量出现 ≥ 2 次 | 提取为 `private enum Field { static let … }` |
| 协议字段名散落在映射与校验两处 | 统一引用同一组具名常量 |
| 模式字符串用数组 `contains` 判断 | 改为 `enum: String` + `init(rawValue:)` |
| 数字字面量（非 0/1/2） | 提取具名常量或加单位注释 |
| 模块间传 `[String: JSONValue]` 等万能字典 | 在模块边界改为具名类型，字面量只留在序列化层 |
| `@unchecked Sendable` | 逐个补注释说明封装的可变性来源 |

检测命令见 `references/defect-catalog.md` 第 2、3 节。

### ⑦ 终检

```bash
swift format lint --recursive --strict $DIRS     # 必须无输出
swiftlint lint --strict --quiet                  # 必须无输出
bash "$SKILL/scripts/verify_citations.sh"        # 若改动了规范正文的引文
```

全干净才能进入报告。

### 测试与构建

- 格式 / 命名整改属于**无行为变更**：不新增测试，但每次提交后必须跑受影响测试。
- 重命名与数据建模调整属于**有行为边界影响**：必须完整回归。
- 按项目 `AGENTS.md` 的测试纪律执行，不要为了让检查通过而放宽任何阈值。

---

## 4. 报告要求

整改结束必须给出报告，至少包含：

1. **前后对比**：格式违规数、语义违规数、`identifier_name` 数、`force_unwrapping` 数。
2. **已自动修复项**：按规则列出数量。
3. **已人工修复项**：逐条列 `文件:行` 与改法。
4. **保留未改项与理由**：第 3 条里「不改」的那些命名，明确列出。
5. **剩余项与理由**：无法修的原因（不是「太麻烦」）。
6. **提交拆分清单**：哪些提交属于格式、哪些属于语义、哪些属于重命名。
7. **未验证项**：如果测试因环境原因没跑，明确写出来，不要含糊。

`scripts/remediate.sh` 会自动生成报告骨架（含第 1 项的实测数字与第 5 项的待办清单），人工整改结果需要补进第 2、3、4、6 项。

---

## 5. 常见半途而废（检查自己有没有犯）

- ❌ 只跑了 `swift format --in-place` 就交付 —— 命名、文档、魔法值、数据建模全没碰。
- ❌ 用 `swiftlint lint`（不加 `--strict`）判断通过 —— warning 被漏过。
- ❌ 为了让 `identifier_name` 归零，把词典收录的可接受词（见 `naming-antipatterns.md` 第 0 节）也改了 —— 制造噪音，违反规范 3.1。
- ❌ 没问排版策略就跑了 `--in-place`，把团队刻意写的手动断行全冲掉。
- ❌ 跳过第 ⑥ 步 —— 工具不报错就当作没问题，魔法字符串原样留在代码里。
- ❌ 把格式修改和新功能写在同一个提交 —— 无法 review、无法回滚。
- ❌ 为提高通过率调高 `line_length` 或关掉规则 —— 必须写进规范的变更记录才允许。
- ❌ 报告只写「已整改」而不给数字 —— 无法验收。
