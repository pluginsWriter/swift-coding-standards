# 第三方内容：许可与署名

**本插件自身的原创内容**（`SKILL.md`、`scripts/`、`assets/`、`README.md` 与本文件，
以及 `references/` 下除 `official/` 外的各篇）以 **MIT** 许可发布，全文见同目录 `LICENSE`。

**`references/official/` 目录是例外**：那里存放的是上游权威来源的**逐字原文快照**，
版权归原作者所有，**不适用上述 MIT 许可**，而分别适用其各自的许可（见下表）。
快照为**未修改的原文**（仅在顶部加了本地来源标注头，未改动正文一字）。

## 来源、版权与许可

| 快照 | 来源 | 版权 | 许可 | 上游地址 |
| --- | --- | --- | --- | --- |
| `s1-api-design-guidelines.md` | Swift API Design Guidelines | Apple Inc. / Swift 项目 | Apache License 2.0 | <https://www.swift.org/documentation/api-design-guidelines/> |
| `s3-swift-format-configuration.md` | swift-format 配置文档 | Apple Inc. / swiftlang | Apache License 2.0 | <https://github.com/swiftlang/swift-format> |
| `s4-stdlib-programmers-manual.md` | Standard Library Programmers Manual | Apple Inc. / swiftlang | Apache License 2.0 | <https://github.com/swiftlang/swift/blob/main/docs/StandardLibraryProgrammersManual.md> |
| `s5-google-swift-style-guide.md` | Google Swift Style Guide | Google LLC | Apache License 2.0 | <https://google.github.io/swift/> |
| `s6-linkedin-swift-style-guide.md` | LinkedIn Swift Style Guide | © LinkedIn Corporation 2016 | Creative Commons Attribution 4.0 International（CC BY 4.0） | <https://github.com/linkedin/swift-style-guide> |

来源登记、抓取地址与冲突取舍的完整说明见 `references/official/SOURCES.md`。

## 本插件遵守的再分发条件

- **Apache License 2.0**（S1 / S3 / S4 / S5）
  - 保留版权、许可与归属声明：各快照顶部的标注头 + 本文件 + `references/official/SOURCES.md` + `references/swift-coding-standards.md` 第 1 章。
  - 随附许可全文：见下「附录：Apache License 2.0」。
  - 未修改原文，故无需声明修改（快照正文逐字保留）。
- **CC BY 4.0**（S6）
  - 保留署名：作者（LinkedIn Corporation）、来源（LinkedIn Swift Style Guide）、许可名称与链接。
  - 标注未作修改；署名头内置于快照顶部，由 `scripts/fetch_official_sources.sh` 在抓取后自动补回、比对时先剥离 —— **请勿手工删除**，否则刷新检测会持续误报。
  - 许可全文：<https://creativecommons.org/licenses/by/4.0/legalcode>

## 只保留链接、未做快照的来源

`references/official/SOURCES.md` 登记的 S2（The Swift Programming Language）**未做本地快照**，
仅保留链接，因此不涉及再分发。

---

## 许可全文

- Apache License 2.0 全文：`LICENSES/Apache-2.0.txt`
  （随附以满足其第 4(a) 条「必须向接收方提供本许可副本」的要求）
- CC BY 4.0 全文：<https://creativecommons.org/licenses/by/4.0/legalcode>
  （CC BY 4.0 第 3(a)(1) 条允许以链接方式提供，故不内置全文）

