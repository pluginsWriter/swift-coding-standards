# AI 代码可维护性：市面方案比对与结合路径

> 建立于 2026-09-17。**未改动任何发布内容**（只在 `.workbuddy/` 内写分析）。
> 起因：用户反馈「规范与可读性已提升，但维护性问题浮现」——① AI 拆解过于细碎、连贯性理解难；
> ② 架构设计（MVVM / MVP / 适配器 / 工厂）在 AI 执行时不被遵循；③ AI 边际动作成本为零
> （加一个 import、拆一个文件、加一个测试点），而人审核维护是真实开销。
> 本文所有「市面」事实来自当日检索（出处见第 6 节）；所有「本工程」事实来自本地实测。
> **排序不是我的主观印象 —— 第 4 节引用的是 plancheck-mcp 确定性评估器的返回结果。**

---

## 0. 结论摘要

**四句话：**

1. **三个新问题不是三个问题，是同一件事的三个切面**：规范覆盖的是「文本怎么排」，
   而这三条都在「结构怎么划」这一层 —— 拆解粒度、架构契约、维护成本，都是**结构层**，
   现有 17 类缺陷**一整层都是空白**。
2. **市面已经收敛出两个有效机制**，且都是「把规则变成可执行判定」而非「把规则写得更详细」：
   **架构 fitness function（架构即代码）** 与 **规格驱动 + 变更/审查预算**。前者治架构漂移，
   后者治审查成本，两者互补而不重叠。
3. **评估结果：P2（生成时前置约束 + 架构声明 + 只读度量）是唯一领先者**，在加权求和与
   TOPSIS 两种聚合下均排第一；**P3（CI 硬阻断架构）触发一票否决** —— 原因是它与本工程既定
   硬约束「AI 生成代码是阻断对象、人工手写只提示」直接冲突，而非它不好。
4. **但排序脆弱**：五个候选全部远低于推荐阈值（最高仅 **0.33 / 100**），证据覆盖率 **0.17**（低）。
   在 `三问题覆盖度` 或 `可检查性` 权重上调 ≥10% 后，P2 的唯一领先地位即消失。
   **结论只在「执行闭环强度」权重不低于当前口径时成立。**

---

## 1. 缺口定位：本工程结构层零覆盖（带锚点）

三个问题在现有规范里**都有对应的位置，但那个位置是空的或只有一半**：

| # | 用户反馈的问题 | 现有落点 | 缺口（实测锚点） |
| --- | --- | --- | --- |
| ① | 拆解过于细碎、连贯性难 | `references/swift-coding-standards.md:512`（5.8） | **只有上限**（函数 60 / 类型 300 / 复杂度 15 / 参数 6），**没有任何下限** |
| ① | 同上 | `references/swift-coding-standards.md:545`（5.10） | 全节只有一句「一个文件只放一个主要类型」，不管「这些单元该不该存在」 |
| ② | 架构（MVVM/MVP/适配器/工厂）不被遵循 | —— | **正文 724 行零处**提及架构层；`references/defect-catalog.md:51-61` 的「纯人工评审」层是唯一的架构质检位，但里面没有任何架构契约 |
| ③ | AI 零成本动作 vs 人的维护开销 | `references/remediation-playbook.md:15-23`（9 条验收） | 9 条全是「代码本身达不达标」，**没有一条是「这次改动的人类成本是否合理」** |
| ③ | 同上 | `assets/swiftlint.yml:95-97` | 已配 `file_length` 700/1200，但**正文零处提及、`verify_consistency.sh` 也不检查** —— 隐式生效，正是「规则多一条、人的核对负担多一分」的实例 |

**机制性原因（与本工程既有诊断一致）**：`SKILL.md:45` 自己写明「机器能查的不靠人自觉」，
但结构层**恰恰是机器查不出的那一层** —— SwiftLint 的 `file_length` / `type_body_length` /
`function_body_length` 全部只报「超过 N」，**没有任何一条规则报「太小」**（详见
`.workbuddy/notes/decomposition-granularity-proposal.md` 第 0 节）。于是：

> **上限规则防臃肿，下限规则防碎片；现有工具链只装备了前者。**
> 叠加一个反向事实：本工程的上限比市面**严 2.7–3.7 倍**（函数 60 vs 160、类型 300 vs 1100、
> 复杂度 15 vs 40），而市面对 AI 友好性的结论是**放宽上限**（locality over hyper-abstraction）。
> **上严 + 下无 = 规则只朝「更碎」一个方向施压**：AI 在 60/300 硬约束下最省力的合规动作就是拆，
> 而拆出来的东西**仍然 0 违规**。

---

## 2. 市面地形：四个方向，各治什么

### 方向 A：架构即代码 / Fitness Function（治「架构不被遵循」）

市面共识是「架构必须是可执行断言，不是文档」：

- **工具形态**：ArchUnit（Java）、NetArchTest（.NET）、dependency-cruiser（JS）。断言形如
  「service 层不得依赖 controller 层」，进 CI 后**编译期/流水线期阻断**。
- **更近的同类（Swift）**：`solid-like-a-rock`（2026-06，SwiftSyntax + Yams）——按 `.solid.yml`
  声明 `dependencyOrder` / `layers` / `deny`，违规输出成普通编译器诊断
  （`Sources/Presentation/HomeView.swift:5: error: layer 'Presentation' must not import 'Data'`）。
  **它的自述定位就是「CI-ready guardrail for AI-assisted development」**，且有 `--freeze`
  存量基线模式（旧工程首日零违规、此后只挡新增）、`init` 从真实 import 图生成初始配置、
  以及把架构图画成 Mermaid 的子命令。
- **更硬的形态（编译期）**：SPM target 边界 —— 没声明依赖就 `import` 不进来，**编译器替你执法**。
  这是 Apple 平台上唯一「零额外工具」的架构约束。
- **更近的同类（Swift 架构契约本身）**：社区已有 `swift-mvvm`、`swift-ui-architect` 等 skill，
  把 MVVM 落成**可判定条目**（如 "Hard rule: No UI framework imports in ViewModels"、
  `layer-dependency-rule`：Domain 层零框架依赖、`state-no-published`：不用 `@Published`、
  `diff-avoid-anyview`：禁用 `AnyView`）。**这是「架构契约」在 agent 形态下的现成写法。**
- **最系统的一家**：ZOZO TECH 的「スキーマでアーキテクチャを縛る」——把 ViewModel/Repository/
  Translator 等每个组件写成 schema（`type` / `imports` / `imports_forbidden` / `depends_on` /
  必需规则 / 禁止模式），YAML 给 AI 与 codegen 用、Markdown 给人 review 用。
  其动机原话值得抄下来：**「ドキュメントによる『努力目標』では、アーキテクチャは守りきれません」**
  （靠文档的「努力目标」是守不住架构的）。

### 方向 B：规格驱动 / 意图层（治「连贯性理解难」）

- **GitHub Spec Kit**（132k+ stars，2026-08-21 发布 1.0）、**AWS Kiro**、DeepLearning.AI 的
  SDD 课程 —— 方法论已从实验期进入主流。核心四个工件：
  `requirements.md`（要什么）/ `design.md`（怎么做）/ `tasks.md`（按序执行）/ `AGENTS.md`（全局约束）。
- **失败模式命名得很好用**：intent drift（模型替你选了合理但非你想要的默认值）、
  hallucinated interfaces（编出不存在的 API 却能编译）、**context collapse（跨会话/跨文件时
  丢掉早先的决定并自相矛盾 —— 这正是「连贯性理解难」的另一面）**。
- **一条反向警告（重要）**：有实证研究 *Why Does CLAUDE.md Keep Growing? Catastrophic
  Remembering in Agentic Coding*（Chakrabarti, 2026）—— 常驻上下文文件会**越堆越大并反而降低输出质量**。
  配套建议是「AGENTS.md 保持 ~150 行的紧凑地图，只做路由，不要把知识堆进去」；
  且判定每一行是否值得留的标准是：**删掉它，agent 会不会犯一个它本来不会犯的错**。
- **一条对齐本工程纪律的观点**：TypeFox 主张「spec 只在能帮助沟通意图时加，其余位置 spec 就是
  代码与测试的第二份副本、又一份要同步的文档」——与本工程「不制造第二份会漂移的权威」同源。

### 方向 C：让规则真的被执行（治「写了但不遵守」）

这一层是**机制**，不是文档，市面已很成熟：

- **文档是建议性的，hook 才是强制性的**。成熟做法分两层：`CLAUDE.md` / `AGENTS.md` 写惯例
  （约 60% 依从率够用），**真正的硬规则写进 hooks**——`PreToolUse` 返回 `exit 2` 是唯一能真的
  拦下 agent 动作的方式（`exit 1` 只记警告、放行）。
- `PostToolUseFailure` 用于**把诊断喂回给 agent 自纠**，而错误信息本身是「指导通道」——
  写错误信息时要写清「哪错了 / 这条规则为什么存在 / 应该改成什么」。
- **一条直接对应本工程处境的结论**：**计算型传感器（快、确定）优先于推断型传感器（需 LLM 判断）**；
  「模块边界」这种事应该**在 ARCHITECTURE.md 里语义说明、由结构性测试来执行** ——
  「**是那个测试让说明变得可信**」。

### 方向 D：审查成本与变更耦合（治「AI 零成本、人高成本」）

这是用户第三点的市面对应物，而且**数据最硬**：

- **审查质量随 diff 大小崩塌**：SmartBear/Cisco（2,500 次评审）指出最佳区间 100–300 LOC / 30–60 分钟，
  **超过 400 行有效性下降**；Propel 的量化：1–200 行缺陷检出率 **87%**、301–600 行 65%、
  **1000+ 行仅 28%**（且 4.2 小时产出的评论数比 45 分钟的还少 —— 是疲劳导致脱离，不是更深入）。
- **AI 的 diff 更大、问题更多**：CodeRabbit 实测 AI PR 的问题数是人工代码的 **1.7 倍**
  （可读性问题 3 倍、逻辑缺陷多 75%）；Vercel 引用的研究显示 PR 量增至 3.1 倍而评审人力只增
  1.5 倍，AI PR 的「首次人工评审→合并」时长多约 20%，且**自动化 AI 评审占比从 19% 升到 84%、
  人工覆盖下降** —— 看板指标不动，真正抓问题的那个环节悄悄停了。
- **变更耦合是这个问题的定量抓手**：CodeScene 的 temporal coupling、GitClear 的 2026 数据
  （重复代码从 40.3 升到 73.0/千次变更；**「移动的代码」从 21% 降到 3.8%**；跨文件调用降 35%）。
  一条最省力的实操指标：**数「一次改动触及几个文件」**（`git log --shortstat -10`）——
  1–2 个为佳，**10+ 说明边界画错**。这与本工程粒度提案第 4 节判据 4「改动半径 1–2 文件」
  **是同一个指标**（市面独立收敛到了同一处）。
- **成本门禁的落地形态**：CI 里的 PR 体积门禁（软 300 / 硬 500，或直接 400）、
  结构化 PR 模板必填「本次实现背后的约束或取舍理由」（2–4 句，CI 校验非空）、
  stacked PR（把跨层改动拆成 schema → API → UI 的有序提交）。
- **一条对本工程的直接提醒**：预算类门禁有反作用 —— 「超预算不进同一提交」可能被满足成
  **拆成更多更小的提交**，单次数字好看而总审核成本不降。所以预算必须**按完整需求累计**，
  而不是按单次提交计。这条已被本次评估列为 P5 的 high 风险。

### 与本工程的关系（不另起一套）

| 结构层问题 | 市面主流机制 | 本工程现状 | 差距性质 |
| --- | --- | --- | --- |
| 架构不被遵循 | 架构即代码（ArchUnit / solid-like-a-rock / SPM 边界 / schema） | 零覆盖 | **缺机制** |
| 连贯性理解难 | SDD 意图层（spec / design / tasks） | 零覆盖 | **缺机制** |
| 规则不被遵守 | 分层：文档建议 + hook 强制 | 只有文档层，无 hook 层 | **缺一半** |
| 维护成本 | 审查预算 + 变更耦合度量 | 零覆盖 | **缺机制** |
| 拆解粒度 | 市面也弱，只有零散清单 | **已有完整提案未合入** | **本工程不落后** |

> 注意最后一行：**粒度这一条我们不落后，反而比市面细**（四条判据 + 九种形态 + 实测基线 +
> 上游 `T-DEC-51`「先起名，再拆」可吸收）。市面同类只有零散的双清单（faion-code-quality 的
> When to Split / When NOT to Split）。

---

## 3. 五个候选方案（含落点与代价）

### P1 · 文档增强：维护性三条款补进规范

最小改动、零新增工具。新增 `references/decomposition-guidelines.md`（粒度判据 + 九种碎片形态 +
体量下限）与 `references/architecture-contracts.md`（MVVM / MVP / 适配器 / 工厂四组可判定条目），
加「四类零边际成本动作须给理由」，并把最关键条文提进 `SKILL.md:49-61` 的「必须记住的高频规则」。
**优点**：落地成本最低（评估给 cost 1/5 分档）。**致命弱点**：执行闭环 1/5 ——
**明确无强制机制，靠 AI 自觉**；且新增阈值与维护对象最多（rulebloat 5/5）。

### P2 · 生成时前置约束：架构声明 + 先自述后写码 + 只读度量 ★ 评估领先

在 P1 文档基础上加**工作流**与**软信号**：(a) 先读项目 `CODING_STYLE.md` 声明的架构形态；
(b) 动手前输出「架构自述」（落在哪一层、新增哪些类型、为什么必须存在 —— 即 `T-DEC-51`
「起不出两个可独立命名的职责就不许拆」）；(c) 新增只读 `scripts/measure_granularity.sh`
（文件行数直方图含 `<30` 计数、函数行数双峰检测、单文件类型声明数、跨文件 extension 按基类型计数、
超宽接口、`git log --shortstat -10` 的改动半径），与 `verify_member_spacing.sh` / `verify_consistency.sh` 同构；
(d) 全部为 S 档软信号，度量并存档、趋势恶化才介入。
**评估给它的分数**：三问题覆盖度 5/5、可检查性 5/5、**执行闭环 5/5（唯一被实际定位验证的锚点
`SKILL.md:49-61`，evidenceHash 已生成）**、落地成本 3/5、规则膨胀 5/5。

### P3 · 架构即代码：边界检查 + 冻结基线 ✗ 评估一票否决

`scripts/verify_architecture.sh` 按 `.architecture.yml` 判定层间 import，`--freeze` 存量基线，
SwiftLint `custom_rules` 覆盖可正则子集，接入终检三连。
**否决原因（评估原文）**：「CI 对所有新增架构违规实施硬阻断，未给出人工手写仅提示的替代路径，
直接冲突于工程明确的阻断对象硬约束；冻结存量不能解决该冲突」。
→ **这是可修的**：加「变更来源标记」（AI 生成 vs 人工手写）后重评即可解除否决。
另有两条实打实的边界：**import 图查不出同模块内的跨层引用**；且本工程主力语言是 Shell（2545 行），
SwiftSyntax 路径不是现成构建链。

### P4 · 规格驱动意图层：ARCHITECTURE.md + 每特性 spec + 验收对照表

治「连贯性」最直接：把连贯性的载体从人脑移到可 diff 的文档，并产出「spec 验收 ↔ `file:line` 证据」
对照表（缺证据标 MISSING）。
**两条必须正视的问题**：被治理工程 `UGDockNative` 根目录**已经有 `AGENTS.md` / `CODING_STYLE.md` /
`CONTEXT.md` 三份上下文文档**，再加 `ARCHITECTURE.md` 就是第四份 —— **权威分工不先定义就会制造
第二份权威**；且市面实证（Chakrabarti 2026）警告常驻上下文会膨胀并**降低**质量。
另外「`file:line` 存在 ≠ 需求已满足」，容易被形式化成交付附件。

### P5 · 审查成本门禁：变更预算 + 规则预算 + 复发性模式台账

直接回应用户第三点：单次提交的改动半径与新增文件数设上限；新增文件 / 依赖 / import / 测试点
四类动作逐项给理由；每条规则必须标注可检查性与维护成本（不容许「写进规范但无检查手段」的规则 ——
`file_length` 就是现成反例）；同规则触发 ≥2 次即起草待审的项目级规则。
**最独立、可与 P1–P4 叠加**，但评估指出其 high 风险：**按单次提交计费会诱发拆提交**，
必须改为按完整需求累计。

---

## 4. 结构化评估结果（plancheck-mcp，确定性引擎）

**口径**：`projectRoot` = 本 skill 工程；6 个维度由我推导（覆盖度 21% / 契合度 17% /
可检查性 21% / 执行闭环 17% / 落地成本 13% / 规则膨胀 13%）；判分模型 gpt-6-astra，single_pass。

### 4.1 分数矩阵与排名

| 排名 | 候选 | 加权分 | 风险扣分 | **总分** | 结论 | 置信度 |
| --- | --- | --- | --- | --- | --- | --- |
| **1** | **P2 生成时前置约束 + 只读度量** | 33.33 | 33 | **0.33** | 未达推荐阈值 | 0.17 |
| 2 | P1 文档增强 | 20.00 | 27 | 0 | 未达阈值 | 0 |
| 3 | P4 规格驱动意图层 | 20.00 | 51 | 0 | 未达阈值 | 0 |
| 3 | P5 审查成本门禁 | 20.00 | 51 | 0 | 未达阈值 | 0 |
| — | P3 架构硬门槛 | 20.00 | 51 | **否决** | **一票否决 · 不可决策** | 0 |

- **领先者（跨算法交叉验证）**：`weighted_sum` → **P2**；`topsis` → **P2**；
  `weighted_product` 未给出唯一领先者 → `consistentAcrossMethods: false`。
- **P2 唯一的 5/5 且被实际定位验证的分项**：**执行闭环强度**（`SKILL.md:49-61`，
  `evidenceStatus: location_verified`，已生成 evidenceHash）。这是它领先的主要来源 ——
  与本工程既定判断「**前置约束 > 事后检测**」同向。
- **五个候选全部远低于 60 分推荐阈值**（最高 0.33）—— 说明**没有一个是「照做即可」的成品方案，
  都需要补设计**（尤其报出的 high 风险项）。

### 4.2 排序稳健性：脆弱（必须说清哪条权重谈拢之前结论不成立）

`robust: false`，`flipPoints: []`，状态 `insufficient_evidence`。扫描结果：

| 维度 | 权重倍数 | 结果 |
| --- | --- | --- |
| 执行闭环强度 | **< ×0.96** | **P2 失去唯一领先** |
| 三问题覆盖度 | ≥ ×1.10 | P2 失去唯一领先 |
| 可检查性 | ≥ ×1.10 | P2 失去唯一领先 |
| 现有机制契合度 | ≥ ×1.14 | P2 失去唯一领先 |
| 落地成本 | ≥ ×1.18 | P2 失去唯一领先 |
| 自身规则膨胀风险 | ≥ ×1.18 | P2 失去唯一领先 |

**读法**：在 **±10%** 内 P2 稳定领先；但**只要「执行闭环强度」的权重下调 4% 以上
（即认为「能真正拦住 AI」没有现在这么重要），或「三问题覆盖度 / 可检查性」上调 10% 以上，
P2 的唯一领先地位就不成立，会与 P1 并列**。所以：

> **结论成立的前提是：你认同「让 AI 在生成时就受约束」比「覆盖面的理论完整度」更值钱。**
> 若你更看重覆盖面，则应把 P1+P2 视为**同一方案的两半**一起做，而不是二选一。

### 4.3 评估报出的必改项（不看分数，看这几条）

**全部候选共同的 high 风险 —— 也是 P3 被否决的同一根因**：

> **没有任何候选定义了「AI 生成代码 vs 人工手写」的区分机制。**
> P1/P4/P5 都被判「生成约束缺口 / 阻断落点与来源区分缺失」。
> 这不是可选项 —— 本工程既定硬约束是「**AI 生成代码是阻断对象，人工手写只提示**」，
> 而 P1/P2/P4/P5 目前都停在声明层，没有可核对的来源标记。

其余按候选：

- **P2**：`high` 双峰检测 / 超宽接口 N 值 / 趋势恶化**三个判定的定义缺失**（"机器能输出数字
  不等于能可靠判断设计退化"）；`medium` 项目架构声明与新架构契约文档的**权威边界未定**。
- **P1**：`high` 执行闭环；`medium` 新增两篇文档的**唯一权威位置未指定**。
- **P4**：`high` 权威来源与文档漂移、验收证据有效性（`file:line` ≠ 语义通过）、生成约束缺口；
  `medium` 维护成本转移（spec 增加审核负担）。
- **P5**：`high` 预算口径偏离（诱发拆提交）、阻断落点与来源区分缺失、规则自身维护成本。
- **P3**：`high` ×4（硬约束冲突、检查覆盖边界、单一权威与规则漂移、运行构建链）。

### 4.4 证据覆盖率的坦白

`整体证据覆盖率 0.17（低）`。原因是多数锚点写作 `文件:行号` 后未能被评估器定位验证
（仅 `SKILL.md:49-61` 通过了 `location_verified`）。**这是本次评估的已知局限**：
分数可用于**相对排序**，不应被读成绝对质量。上面 4.1 的分数与 4.2 的阈值来自工具返回，
第 1 节的锚点是我本地实测（grep 已核对），两者可分别复核。

---

## 5. 推荐路径：一条主链 + 两条配套（含具体结合点）

评估给出的排序是 **P2 独走**，但 P1 是 P2 的**前提**（P2 依赖 P1 的两篇文档），
P5 被评估明确建议「作为精简后的配套」而不是独立方案。因此推荐**按依赖关系组合**，
而不是选一个：

### 主链：P1 → P2（第一步做什么）

| 步 | 动作 | 落点 | 结合到的现有机制 |
| --- | --- | --- | --- |
| 1 | 写粒度判据与体量下限 | 新 `references/decomposition-guidelines.md` | 判据只写一处，`SKILL.md:49-61` 只放**执行要求**并引用它 |
| 2 | 写四组架构契约（MVVM/MVP/适配器/工厂） | 新 `references/architecture-contracts.md` | 挂进 `references/defect-catalog.md:51-61` 的人工评审层 |
| 3 | 最关键条文提升为生成时约束 | `SKILL.md:49-61`「必须记住的高频规则」 | **这是评估唯一验证通过的前置约束落点** |
| 4 | 要求 AI 先输出架构自述、再写码 | `SKILL.md`「场景二：写/改 Swift 代码」 | 与既有「先起名再拆」（`T-DEC-51`）同一动作 |
| 5 | 只读度量脚本 | 新 `scripts/measure_granularity.sh` | 与 `verify_member_spacing.sh`、`verify_consistency.sh` **同构**（只读 / `--check` / `--quiet`） |

**对第 5 步的强制要求（评估 high 风险）**：三个判定必须先定义再实现 ——
「趋势恶化」的触发条件、超宽接口的 N 值、双峰检测的**解析范围与不可判定时的输出**。
口径未定义就不要写进脚本；按本工程纪律，**说不清怎么判定的指标不得进入任何档位**。

### 配套一：来源标记（解除 P3 否决，也是全部候选的必改项）

在提交说明 / 提交信息里加一条可机读的来源标记（如 `Assisted-by:` 尾注，市面已有同类做法），
让「AI 生成」与「人工手写」可区分。**这一步不做，架构硬门槛永远过不了本工程自己的硬约束**；
做了之后 P3 才具备重评资格。这是**成本最低、解锁最多**的一步。

### 配套二：规则预算（把 P5 精简成一条）

不要全套预算门禁，只保留评估判定为最有效的那半条 ——
**「每条规则必须标注可检查性与维护成本，不许存在无检查手段的规则」**，
并**先把 `file_length`（`assets/swiftlint.yml:95-97`）这个现成的隐性违纪补上**：
要么写进正文与 `verify_consistency.sh`，要么从模板里删掉。
改动半径预算按评估意见改为**按完整需求累计**，不按单次提交计。

### 明确不做的（本轮）

- **不引入 CI/CI 硬门槛**：本工程无 CI（评估已作为 constraint 记录），且 CI 阻断与来源纪律冲突。
- **不引入 `ARCHITECTURE.md` 作为第四份上下文文档**：先把 `AGENTS.md` / `CODING_STYLE.md` /
  `CONTEXT.md` 三者的权威边界定清，否则是制造第二份权威（P4 的 high 风险）。
- **不擅自改动发布内容**：本轮只出方案，等批准。

---

## 6. 与 DEC 规则族、粒度提案的关系（不另起一套）

- 粒度部分**直接沿用** `.workbuddy/notes/decomposition-granularity-proposal.md` 的四条判据与
  H/S/J 分档，**不重新推导**；该提案第 12.4 节的挂起条件仍然有效（`T-DEC-00a` 通过前
  不得声称其四条判据等同上游 §5.3「四问」，也不得据此改写上游措辞）。
- 与 `~/Desktop/2026-09-14-decomposition-rollout-plan.md` 的分工不变：
  **判据共享、阈值文件不共享**（Swift 侧阈值不得并入 C++ 侧宿主）。
- 本次新增的可回馈项：市面 **`solid-like-a-rock`** 与 **ZOZO 的 schema 方案**是两个现成参照，
  可作为 C++ 侧 `T-DEC-03`「纯转发能否机器检出」的跨语言对照 —— **Swift 侧有 `swift-syntax`
  完整 AST，且已有第三方工具做通了 import 边界判定**，证明这不是不可实现的事。

---

## 7. 本次核实到的事实与出处

**本机实测（2026-09-17）**
| 项 | 结果 |
| --- | --- |
| 工程内容文件 | 21 个（`SKILL.md` 210 行 + `references/` 9 篇 + `assets/` 2 + `scripts/` 6） |
| 5.8 现状 | `references/swift-coding-standards.md:512`，仅上限 |
| 5.10 现状 | `references/swift-coding-standards.md:545`，仅一句 |
| 架构提及 | 正文 724 行零处架构层规则 |
| `file_length` | `assets/swiftlint.yml:95-97` 配 700/1200，正文零处、自检不覆盖 |
| CI / 测试 | 无（评估器作为 constraint 记录） |
| 被治理工程 | `UGDockNative`：SwiftPM、`AGENTS.md` / `CODING_STYLE.md` / `CONTEXT.md` / `.swift-format` / `.swiftlint.yml` / `Tools` / `Tests` |

**市面事实的出处**
- GitHub Spec Kit（1.0 / 132k stars / 阶段命令）：`devtoollab.com/blog/spec-driven-development-ai-agents`
- 「Catastrophic Remembering」与 AGENTS.md 保持 ~150 行：`thinkinginsidethebox.ai`（2026-08-16）、`typefox.io/blog/software-projects-for-ai-agents`
- 架构漂移与 fitness function：`techdebt.works/ai-architecture-drift/`、`icentricagency.com/insights/the-hidden-cost-of-ai-generated-code-architectural-drift`
- ArchUnit / NetArchTest / dependency-cruiser 作为 AI 护栏：`clawdbytes.com`（2026-09-14）
- Swift 侧 import 边界 linter（含 `--freeze`、SwiftSyntax、TCA）：`forums.swift.org/t/.../87293`（2026-06）
- ZOZO「スキーマでアーキテクチャを縛る」：`techblog.zozo.com/entry/architecture-codegen-pipeline`
- MVVM / SwiftUI 架构契约类 skill：`lobehub.com/skills/tobitech-swift-mvvm`、`lobehub.com/zh/skills/pproenca-dot-skills-swift-ui-architect`
- hook 强制与「文档建议 + hook 强制」两层：`juejin.cn/post/7641855151042068526`、`zarar.dev/agent-hooks-deterministic-guardrails-for-ai-generated-code`、`code.claude.com/docs/en/agent-sdk/hooks`
- 审查成本数据（SmartBear/Cisco、Propel、CodeRabbit）：`agentpatterns.ai/anti-patterns/law-of-triviality-ai-prs/`
- PR 体积门禁与「队列深度是领先指标」：`vercel.com/i/evaluating-ai-coding-agents`、`vector-labs.ai/insights/why-ai-generated-code-is-making-your-review-process-slower-not-faster`
- 变更耦合 / 数改动触及文件数：`dev.to/dancristian_podina_0b537/...`（引 CodeScene temporal coupling、GitClear 2026、Ousterhout）

**未核实 / 需谨慎**
- 市面 agent 类方案（各类 skill）多为**社区实验**，列它们是为说明「方向已被探索」，不是「应照抄」。
- `solid-like-a-rock` 的 `--freeze` 在真实存量工程上的表现**未实测**（本机未安装）。
- 评估器证据覆盖率仅 0.17，分数适合相对排序，不适合绝对解读。
- 体量下限的具体数值（30 行 / 2 成员）**仍未在第二个工程上校准**（沿用粒度提案第 11 节的挂起状态）。

---

## 8. 待裁决

1. **是否接受 P1→P2 主链**（含第 5 节第 5 步的三个判定必须先定义）？
2. **是否先做「来源标记」**（配套一）？它是解锁架构硬门槛的唯一前提。
3. **是否同意把 `file_length` 的隐性违纪一并补掉**（配套二）？
4. **是否要我把评估配置写回 `eval.config.json`**？默认不写 —— 按本工程纪律，
   写回等于把评分规则纳入版本控制，需你确认。（`dimensions` 与权重也是我推导的，可调。）
