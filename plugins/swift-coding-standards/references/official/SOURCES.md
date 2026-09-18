# 权威来源登记与本地快照

本目录存放 `references/swift-coding-standards.md` 第 1 章所引用来源的**原文快照**，以及来源登记信息。

> **目录名说明**：目录名是历史命名。它实际存放的是「本规范的权威来源原文」，其中 **S1–S4 为 Swift / Apple 官方**，**S5 / S6 是行业权威，不是官方文档**（见下表「性质」列）。

## 为什么需要本地快照

规范正文本身**不联网** —— 规则已逐条转述进正文。快照解决的是另外两个问题：

1. **上游会消失**：S4 原先指向的 `docs/Style.md` 已被官方从所有分支与标签移除（实测 404），内容并入 `docs/StandardLibraryProgrammersManual.md`。只有链接而没有快照，规范就会在无声中失去依据。
2. **网络不可靠**：`raw.githubusercontent.com` 在部分网络与代理环境下超时率明显，CI 与离线环境不应依赖实时抓取。

快照还使「引文纪律」可执行：正文中凡标注为原文的句子，必须能在本目录中逐字检索到。

## 来源登记表

| 编号 | 名称 | 性质 | 权威范围 | 页面地址 | 快照文件 |
| --- | --- | --- | --- | --- | --- |
| S1 | Swift API Design Guidelines | Apple / Swift **官方** | 命名、参数标签、文档注释、词汇选择（**唯一权威**） | <https://www.swift.org/documentation/api-design-guidelines/> | `s1-api-design-guidelines.md` |
| S2 | The Swift Programming Language | Apple **官方** | 语言语义、可选值、并发、错误处理 | <https://docs.swift.org/swift-book/> | 无（见下） |
| S3 | swift-format | Apple **官方**格式化器 | 缩进、断行、花括号、分号、import 顺序 | <https://github.com/swiftlang/swift-format> | `s3-swift-format-configuration.md` |
| S4 | Standard Library Programmers Manual | Swift **官方**（stdlib 范围） | 缩进、行长、断行、代码组织 | <https://github.com/swiftlang/swift/blob/main/docs/StandardLibraryProgrammersManual.md> | `s4-stdlib-programmers-manual.md` |
| S5 | Google Swift Style Guide | 行业权威（**非官方**） | S1/S3 未覆盖处的格式补充 | <https://google.github.io/swift/> | `s5-google-swift-style-guide.md` |
| S6 | LinkedIn Swift Style Guide | 行业参考（**非官方**） | 数据建模、可选值、`guard`、注释与文件级细则 | <https://github.com/linkedin/swift-style-guide> | `s6-linkedin-swift-style-guide.md` |

**S2 不提供快照**：The Swift Programming Language 是一本多文件书籍，没有单一可抓取的 Markdown 源。其涉及的语言语义属于编译器与语言参考范畴，本规范的引用密度低，保留链接即可。

抓取用的原始地址（raw）记录在 `.fetch-manifest.tsv` 的第 5 列，不在此重复，避免两处维护。

## S6 的定位与冲突

S6 是 **LinkedIn 的 Swift Style Guide**（2016 年起维护，2024-12 起对齐 swift-format 默认风格），是**行业参考而非官方文档**。它与 S1/S3 存在实质冲突，因此本规范**只采纳其中若干条**，且**冲突时一律以 S1 / S3 与本标准为准**。

完整冲突取舍表见 `references/swift-coding-standards.md` 的 **1.3 节**。摘要：

| 处置 | 议题 |
| --- | --- |
| **采纳** | 关联值必须具名；元组 ≤ 2 成员；有限枚举禁用 `default`；禁用 `unowned`；测试用 `XCTUnwrap`；`internal` 可省略；文件尾换行 / 无行尾空白；`//` 后留空格 |
| **不采纳** | 文档注释用 `/** */`（应 `///`）；行长 160 列；禁止单行 `guard ... else { return }`；类方法简写限制；禁止 `+=` 追加数组 |

## 分发方式：内置随 skill 走，不在集成时下载

快照文件**直接内置在本目录**，随 skill 一起分发。集成、复制、移动到任何位置都不需要联网，引用关系也不会断。

对比过的两种策略：

| | 内置（当前采用） | 集成时自动下载 |
| --- | --- | --- |
| 版本确定性 | **同一 skill 版本 = 同一份规范文本**，引文校验可复现 | 同一版本在不同机器上拿到不同文本，校验结果不一致 |
| 失败模式 | **无** | 下载失败即快照缺文件 |
| 离线 / 受限网络 | **可用** | 不可用（企业网络常见封禁该域名） |
| 体积成本 | 约 224 KB（6 个文件） | 0 |
| 上游跟进 | 需显式刷新（可用 `--freshness` 检测） | 天然最新 |

决定采用内置，理由按权重排序：

1. **快照的意义就是版本确定。** 一个会随集成时机变化的「快照」，无法支撑「引文必须逐字可检索」这条纪律 —— 同一份规范在不同机器上会得出不同校验结论，规范失去可复现性。
2. **体积成本可忽略。** 6 个文件合计约 224 KB，不值得为此引入一个网络失败模式。
3. **网络确实不可靠。** 实测 `raw.githubusercontent.com` 存在整段时间的连接失败与挂起；一次失败就会让快照缺文件。
4. **受限网络下集成时联网往往根本不可行。**

内置带来的唯一代价是**可能滞后于上游**，因此提供显式检测手段（见下）。

## 使用方式

```bash
SKILL_DIR="$HOME/.workbuddy/skills/swift-coding-standards"   # 本 skill 所在目录；在别的机器/别的 agent 上路径不同，按实际位置改

# —— 集成后自检（纯离线，不需要网络）——
bash "$SKILL_DIR/scripts/verify_citations.sh"                   # 双向校验引文与快照
bash "$SKILL_DIR/scripts/fetch_official_sources.sh" --status    # 查看哈希、体积、抓取时间

# —— 维护者巡检（需要网络，都不会静默改文件）——
bash "$SKILL_DIR/scripts/fetch_official_sources.sh" --freshness # 对比上游，判断是否过期
bash "$SKILL_DIR/scripts/fetch_official_sources.sh" --check     # 只校验各源是否可达

# —— 确认需要跟进后才刷新（会改写快照）——
bash "$SKILL_DIR/scripts/fetch_official_sources.sh"
```

`--freshness` 与 `--check` **只报告、不修改**；刷新是主动动作，属于规范依据的变更，应记入正文附录 C 的变更记录。

> **实现注意**：S6 的快照顶部有本地来源标注头（版权 + 许可，CC BY 4.0 要求保留）。脚本在抓取后会自动把标注头补回、在比对时先剥离，因此在 `SOURCES` 表中该条目的第 4 列声明了标注头行数。改动这条时不要漏掉该字段，否则 `--freshness` 会持续误报上游已更新。

## 快照过期的处理流程

1. `--freshness` 报出差异 → 先判断差异是否触及规范正文引用的句子。
2. 执行刷新，然后重跑 `verify_citations.sh`：
   - 通过 → 上游改动与本规范引文无关，更新附录 C 记录即可。
   - 失败 → 上游改写了被引用的句子，**以来源为准**，同步修正正文（去掉引号改为转述，或更新为新的原文）。
3. 引用关系变动较大时，走规范自身的版本号递增。

## 引文纪律

- 正文中加引号或斜体的英文句子 = **来源原文**，必须逐字可在快照中检索到。
- 转述、翻译、改写一律**不加引号**，避免把改写句伪装成原文。
- **双向校验**：`verify_citations.sh` 同时检查两个方向 ——
  - `BAD`：引文表里的句子在快照中找不到（误引）；
  - `ORPH`：引文表里登记了正文其实没引用的句子（引文表虚挂）。
  两个方向都必须干净，否则说明正文与引文表已经漂移。

## 归属与许可

快照文本版权归原作者所有，此处仅为本地参考副本。文本可能滞后于上游，**以来源在线版本为准**。

| 来源 | 许可 | 重分发要求 |
| --- | --- | --- |
| swift-org-website（S1）、swift-format（S3）、swift（S4） | Apache License 2.0 | 保留版权与许可声明 |
| google/swift（S5） | Apache License 2.0 | 同上 |
| linkedin/swift-style-guide（S6） | **CC BY 4.0**（Ⓒ LinkedIn Corporation 2016） | **必须保留署名与许可** —— 已内置于快照顶部标注头，抓取脚本会自动维护，请勿手工删除 |

重新分发本 skill 时，请保留本文件与各快照文件顶部的来源标注。
完整的第三方署名、各来源许可与再分发条件另见插件根目录的 `THIRD-PARTY-NOTICES.md`，
其中随附 Apache License 2.0 全文（`LICENSES/Apache-2.0.txt`）以满足其第 4(a) 条要求。
