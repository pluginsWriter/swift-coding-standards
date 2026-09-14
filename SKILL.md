---
name: swift-coding-standards
description: 所有 Swift 工程的默认编码规范与强制工具链（swift-format + SwiftLint）。任何写、改、评审、重命名、格式化或迁移 Swift 代码的工作默认遵循本规范，无需用户显式点名。覆盖命名（判据是「调用点能否读懂」而非禁用常见词）、格式（人工排版与工具排版同等有效）、注释与文档、语言与并发约束、体量上限、常量与魔法值、17 类缺陷检测、权威来源离线快照与引文校验、基线采集与五批迁移，以及既有代码的完整整改流程（必须格式化 + 命名 + 文档 + 语言约束全部到位，不得只跑格式化就收尾）。触发场景与触发词清单见正文「何时使用」。
agent_created: true
compatibility: Requires a Swift 6.x toolchain (for the bundled `swift format`) and bash with awk. SwiftLint is recommended for semantic rules (verified against 0.63; rule names may drift across major versions). All reference snapshots are bundled, so no network access is needed. Works on macOS and Linux; SwiftPM and .xcodeproj projects are both supported.
---

# Swift 编码规范（跨项目）

为任意 Swift 工程提供**统一的命名、格式、注释与语言约束标准**，并配套可直接落地的强制工具链（swift-format + SwiftLint）。

## 默认生效（无需显式唤起）

**本规范对 Swift 代码默认生效。** 用户不需要说「请按编码规范来」，也不需要在提示里带上本 skill 的名字 —— 只要这次工作涉及 Swift 代码，就按本规范执行。

- **不要等被点名**：涉及 Swift 代码时，先加载并应用本 skill，再动手写或改。
- **不要自行取舍风格**：用户未指定风格时一律以本规范为准，不要在几种常见风格之间「看情况」。
- **写完即自检**：改动 Swift 代码后按附录 A 清单自检。
- **默认不等于擅自扩大改动**：默认生效指**风格判定**默认遵循本规范，不是默认去批量整改存量代码。大规模重命名 / 格式化仍需用户批准。

## 两条最容易搞反的原则

**1. 命名只针对「读不懂」，不针对「不眼熟」。**
中文开发者普遍熟悉的常用词与高频缩写**明确可以接受，不要要求重命名**——完整可接受词表以 `references/naming-antipatterns.md` 第 0 节词典为**唯一权威**，各文件只引用、不复制（此前 `drain` 在词典与整改手册间漂移，根源就是多处副本）。真正要改的是三类：生僻词（`reify`/`thunk`/`amortize`）、自造缩写与单字母（`aniDur`/`l`/`w`）、对象或返回值无从判断。判据只有一条：**遮住定义只看调用点，陌生人能否说出这行在做什么。**

**2. 人工排版与工具排版同等有效。**
格式有两个合法来源：`swift format` 的输出、以及开发者手写的排版。**`--in-place` 不是提交前必做动作**；钩子与 CI 只做 `lint` 检查，禁止自动改写源码。手动断行、对齐等被保留（`respectsExistingLineBreaks: true`），需要长期豁免某处就加 `// swift-format-ignore`。必须改的只有这几类：分号、块内多语句压行、`defer{`、关键字与花括号之间缺空格，以及**成员之间缺分隔空行** —— 前四类 `swift format lint` 会报，**最后一类两类工具都查不出**，得跑 `scripts/verify_member_spacing.sh`（见正文 4.7）。

## 何时使用

- 编写、修改、评审任何 Swift 代码
- 用户抱怨代码不规范、命名难懂、格式混乱、注释缺失
- 需要新建或调整 `.swift-format` / `.swiftlint.yml`
- 需要为工程建立编码规范 / 注释规范文档，或做规范迁移
- 提交前自检、配置 CI 的代码检查步骤

**触发词**（对话中出现任一即应加载本 skill；description 已压缩，完整清单在此维护）：Swift 代码规范、Swift 编码规范、Swift 命名、Swift 注释规范、文档注释、代码风格、code style、swift-format、SwiftLint、lint 配置、命名不好、一行多语句、defer、格式整改、规范化代码，以及 Swift review / code review、重构、重命名等场景。

## 核心原则

> **Swift 官方没有单一格式标准。** 命名有官方标准（S1），格式的官方基线是 Apple 的 swift-format 格式化器，两者之外的细节才参考 Google / LinkedIn 风格指南。

- 命名、参数标签、文档注释 → 100% 采用 **Swift API Design Guidelines（S1）**
- 格式 → 以 **swift-format（S3）** 默认行为为准，用 `.swift-format` 固化
- 机器能查的不靠人自觉：缺陷表标为「能机器检出」的类别都配了检查命令（见 `references/defect-catalog.md`）—— 格式类走 `swift-format`、语义类走 `SwiftLint`，成员间缺分隔空行走 `scripts/verify_member_spacing.sh`
- 人工评审聚焦三件事：**命名是否可读**、**设计是否合理**、**注释是否说明契约而非复述代码**

## 必须记住的高频规则

- **禁止分号**：一行一条语句、一行一个 `case`、一行一个变量声明。
- **花括号必须换行**：块内出现 ≥ 2 条语句时禁止压成一行；`{` 与关键字之间必须有空格（`defer {`，禁止 `defer{`）。
- **`defer` 写法**：块内 1 条语句可单行 `defer { lock.unlock() }`，≥ 2 条必须换行展开。
- **允许单行的白名单**：`defer`（单语句）、`guard ... else { return }`、单表达式函数体 / 计算属性、单语句 `switch` case、单表达式闭包。其余一律多行。
- **禁止强制解包族**：`!`、`try!`、`as!`、隐式解包可选（`@IBOutlet` 除外）、`unowned`。测试里用 `XCTUnwrap`。
- **数值参数必须带单位**：`timeoutMilliseconds` 而非 `timeout`，`byteCount` 而非 `size`。
- **禁止自造缩写与单字母**：`aniDur`、`l`、`r`、`w`、`h`、`n` 展开。
- **工厂方法用 `make` 前缀**；不加 `get` 前缀。
- **元组最多 2 个成员**；关联值必须具名（`case wallpaper(displayIDs:filePath:mode:)`）。
- **`public` 声明必须有 `///` 文档注释**，且说明参数 / 返回值 / Throws 条件。
- **禁止魔法字符串**：同一字面量出现 ≥ 2 次必须提取具名常量。
- **体量上限**：函数 60 行、类型 300 行、复杂度 15、参数 6 个。

## 工作流

### 场景零：集成后自检（默认执行，纯离线）

本 skill **内置权威来源原文快照**（`references/official/`，含 S1–S6），随 skill 一起分发 —— 集成、复制、移动后都**不需要联网、不需要下载**，引用关系不会断。

```bash
bash <skill-dir>/scripts/verify_citations.sh
```

它校验规范正文中标注为原文的句子与快照逐字一致，并会在快照缺失时明确报错。此步骤零网络、秒级完成。

更新快照是**维护者的主动动作**，不是集成步骤：

```bash
bash <skill-dir>/scripts/fetch_official_sources.sh --freshness  # 联网对比上游，只报告
```

### 场景零之二：内部一致性自检（改完 skill 后跑，纯离线）

SKILL.md、规范正文、整改手册、命名词典、两个模板资产之间存在多处**同一事实的副本**（验收条数、版本号、缩进/行长、规则分工、引文表）。历史上正是这些手抄副本造成了漂移。

```bash
bash <skill-dir>/scripts/verify_consistency.sh          # 不一致记 FAIL，已知待决项记 WARN
bash <skill-dir>/scripts/verify_consistency.sh --strict # 待决项也算 FAIL
```

期望值一律**从单一权威来源推导**（条数取自手册表格行数、版本号取自变更记录末行、阈值取自模板资产），不在脚本里写第二份硬编码 —— 硬编码只会制造下一个漂移源。

### 场景一：为工程安装规范工具链

```bash
bash <skill-dir>/scripts/bootstrap_swift_style.sh <工程目录> --check
```

脚本会检测工具、安装 `.swift-format` 与 `.swiftlint.yml`、并输出违规基线。要执行修复，显式加 `--fix`（会修改源码，执行前必须先向用户确认）。

### 场景二：写 / 改 Swift 代码

1. 命名看第 3 章（拿不准查 `references/naming-antipatterns.md` 的快速替换表）。
2. 格式看第 4 章；**人工排版同样合规**。
3. 注释看 `references/comment-standards.md`。
4. 写完运行：

   ```bash
   swift format lint --recursive --strict Sources Tests
   ```

### 场景三：评审既有代码

1. 采集基线：

   ```bash
   swift format lint --recursive Sources Tests 2>&1 | grep -oE '\[[A-Za-z]+\]' | sort -u \
     | grep -oE '\[[A-Za-z]+\]' | sort | uniq -c | sort -rn
   swiftlint lint --quiet 2>&1 | grep -oE '\([a-z_]+\)$' | sort | uniq -c | sort -rn
   ```

   注意两个坑：`swift format lint` 输出走 **stderr**（不要 `2>/dev/null`），且会**重复输出**约 3.5 倍（必须 `sort -u`）。
2. 按第 8 章的分批策略给出计划，**不要一次性改完就提交**。
3. 报告时区分「格式类（可机械修复）」与「命名 / 设计 / 注释类（需评审）」。
4. 排查面要超出「命名 / 分号 / 花括号」三项 —— 用 `references/defect-catalog.md` 的 17 类缺陷逐类过一遍。

### 场景四：为工程建立规范文档

在工程根目录创建 `CODING_STYLE.md`，**只写项目特有内容**（模块结构、错误码体系、领域术语表、技术栈约束、既有基线、迁移排期），并声明遵循本 skill 的通用标准。不要把通用规则复制进去 —— 复制会产生版本分裂。

### 场景五：显式要求「把代码改规范」时的完整整改

用户明确说「按规范改」「把不规范的地方改掉」时，**不能只跑一次格式化就交付** —— 格式化不碰命名、文档、魔法值和语言约束，而后者恰恰是用户抱怨的重点。按 `references/remediation-playbook.md` 执行：

1. **先读手册第 1 节**，确认「完整」的 9 条验收标准。
2. 采集基线、生成报告骨架与待办清单（只读）：

   ```bash
   bash <skill-dir>/scripts/remediate.sh <工程目录> --check
   ```

3. 获用户批准后执行机械修复（**只解决格式**，会改源码）：

   ```bash
   bash <skill-dir>/scripts/remediate.sh <工程目录> --fix
   ```

   脚本会打印前后对比与剩余违规数，**并明确拒绝把「只修了格式」当作完成**。
4. **继续处理报告「待人工处理清单」，直到清零**：

   | 规则 | 整改动作 |
   | --- | --- |
   | `identifier_name` | **先按 3.1 判据筛一遍**：可接受词（词表唯一权威：`references/naming-antipatterns.md` 第 0 节）一律不动；只改生僻词、自造缩写、单字母、超长名 |
   | `missing_docs` | 按 `references/comment-standards.md` 补 `///`：摘要 → 参数 → 返回值 → Throws |
   | `force_unwrapping` / `force_try` | 改 `guard let` / `do-catch`；测试用 `XCTUnwrap` |
   | 大元组 / 无标签关联值 | 改具名 `struct` 或补参数标签 |
   | 魔法字符串 | 提取具名常量（正文 5.9） |
   | 数值参数缺单位 | 补量纲（`timeoutMilliseconds`） |

5. 终检**必须三条都干净**：

   ```bash
   swift format lint --recursive --strict <dirs>                    # 必须无输出
   swiftlint lint --strict --quiet                                  # 必须无输出（注意 --strict）
   bash <skill-dir>/scripts/verify_member_spacing.sh <dirs> --quiet    # 必须 0 处（前两条查不出）
   ```

6. 把人工整改结果补进报告，**如实列出剩余项与理由**。

> **判定「完整」的唯一标准是手册第 1 节的 9 条全部满足**，而不是「跑过脚本了」。只做了格式就等于没做完，必须明确告诉用户还剩什么、为什么。另外：`unused_import` 一类规则需要 `swiftlint analyze`，`lint` 不会报 —— 没有输出不等于达标。

## 工具链要点

- **`swift format` 随 Swift 6.x 工具链自带**，先试它，不要再无脑 `brew install`。
- **分工必须清晰**：`swift-format` 管格式，`SwiftLint` 管语义。`assets/swiftlint.yml` 已把全部格式规则显式禁用，避免两套工具冲突。
- **尊重人工排版**：`respectsExistingLineBreaks` 不得关掉；局部豁免用 `// swift-format-ignore`。
- **缩进与 Xcode 编辑器对齐（2026-09-11 决定，替代 09-10 的 2 空格 / 100 列）**：**每层 4 空格 / 行长 120 列**，并开启 `indentSwitchCaseLabels` 与 `indentConditionalCompilationBlocks`。
  - `.swift-format` 的 `indentation.spaces = 4`、`lineLength = 120`、`indentSwitchCaseLabels = true`、`indentConditionalCompilationBlocks = true`，与 `.swiftlint.yml` 的 `line_length.warning = 120` —— 五者必须始终一致。
  - **适用全部嵌套构造**：类型 / 函数体、if / for / while / do-catch / guard、闭包体、switch 的 case（含多层嵌套）、#if 块内容 —— 每层一律 +4，与 Xcode 回车后的自动缩进完全一致，写码不再与格式化打架。
  - **两个必须显式开启的开关**：swift-format 默认把 `case` 拍回与 `switch` 同级（`indentSwitchCaseLabels` 默认 false）；`indentConditionalCompilationBlocks` 默认虽为 true，但旧模板显式设过 `false`，集成时检查别把旧值带回来。
  - 存量工程迁移时**一次性接受工具全量重排**，不做两段式过渡。
- **配置缺失 / 作用域为空 = 假基线，必须挡住**：`remediate.sh` 在缺少 `.swift-format` 或 `.swiftlint.yml` 时自动从 skill 资产模板生成缺失文件，并把 `included` 改写为实际检查目录（防 Xcode 工程空扫报 0）；只新增、绝不覆盖已有配置，生成失败才退出码 4。`--allow-missing-config` 的含义是「跳过自动生成、坚持无配置采基线」。
  - 实测（swiftlint 0.63）：同一段 `print(value!)`，无 `.swiftlint.yml` 时报 **0 条**，有配置时报 1 条 `force_unwrapping` —— opt_in 规则在无配置时完全不生效。
  - 更隐蔽的一种：`.swiftlint.yml` 的 `included` 是相对**配置文件所在目录**解析的；列出的目录不存在时（典型是 Xcode 工程没有 `Sources/`）SwiftLint 一条都不扫，同样报「0 违规」。脚本会检测并拒绝。
  - 确实要在无配置下采基线，才显式加 `--allow-missing-config`（报告里会标注基线不可信）。
- **源码目录按工程形态确定**：脚本默认探测 `Sources` + `Tests`；`.xcodeproj` / `.xcworkspace` 工程通常没有这两个目录，会回退到整个工程根并可能扫到 `DerivedData/`、`Pods/` —— 必须用 `--dirs "<目录…>"` 显式指定，并同步修改 `.swiftlint.yml` 的 `included` 为同样的目录。

## 迁移纪律

- 格式迁移是**无行为变更**的提交：不新增测试，但每次提交后必须跑受影响的测试。
- 重命名与数据建模调整是**有行为边界影响**的变更：先写 ADR，再对受影响测试完整回归。
- **严禁把格式修改与逻辑修改放进同一个提交。**
- 禁止为提高通过率而放宽阈值；放宽阈值必须写进规范的变更记录。

## 参考文件

- `references/swift-coding-standards.md` —— **完整规范**：17 类缺陷全景、命名、格式（含人工排版边界）、语言与设计约束、注释、测试、工具链、五批迁移
- `references/comment-standards.md` —— **注释与文档规范**：`///` 使用范围与结构、DocC 标记、MARK、TODO/FIXME、并发注释、维护要求、Review 清单
- `references/defect-catalog.md` —— **缺陷目录与检测方法**：每一类的检测命令、整改动作、真实样本、排查顺序
- `references/naming-antipatterns.md` —— 生涩命名反模式词典与快速替换对照表（含「不查什么」清单）
- `references/remediation-playbook.md` —— **完整整改手册**：9 条验收标准、整改顺序、逐类动作、报告要求、常见半途而废
- `references/official/SOURCES.md` —— 权威来源登记表、分发策略、引文纪律、S6 冲突与取舍
- `references/official/*.md` —— 权威来源原文快照（S1–S4 官方，S5/S6 行业权威），**随 skill 内置分发**（勿手工编辑）
- `assets/swift-format.json` —— swift-format 配置模板（安装时复制为 `.swift-format`）
- `assets/swiftlint.yml` —— SwiftLint 配置模板（安装时复制为 `.swiftlint.yml`）
- `scripts/bootstrap_swift_style.sh` —— 工具链安装与基线采集
- `scripts/remediate.sh` —— **完整整改管线**：基线 → 机械修复 → 复检 → 待办清单 → 报告（`--check` / `--fix`）
- `scripts/fetch_official_sources.sh` —— 快照巡检与刷新（`--status` 离线；`--freshness` / `--check` / 刷新需联网）
- `scripts/verify_citations.sh` —— 离线校验正文引文与快照是否逐字一致（含反向启发扫描：正文斜体英文句必须有快照出处）
- `scripts/verify_consistency.sh` —— skill 内部一致性自检：验收条数、版本号、缩进与行长、规则分工、frontmatter 限额；期望值一律从单一权威来源推导，不写第二份硬编码
- `scripts/verify_member_spacing.sh` —— **成员间空行检查**：swift-format 与 SwiftLint 都查不出这条规则，只能靠它（`--check` 只读 / `--fix` 只插空行）；判据与已知漏检边界写在脚本头部
