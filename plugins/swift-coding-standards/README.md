# swift-coding-standards

所有 Swift 工程的**默认编码规范与强制工具链**（swift-format + SwiftLint）。
本文件随插件一起分发，因此自足 —— 不需要读仓库其它部分也能装好、用起来。

## 是什么

给任意 Swift 工程提供统一的**命名、格式、注释、语言与并发约束、体量上限**标准，
并配套可直接落地的检测与整改管线。核心特征：

- **默认生效**：涉及 Swift 代码时无需显式点名，风格判定一律以本规范为准。
- **判据优先于清单**：命名只针对「调用点读不懂」，不针对「词不眼熟」——`normalize`、`perform`、`u16` 这类常用词明确可接受，不制造无意义重命名。
- **约束力 ≈ 可检查性**：每条规则都标注是机器可查还是需人工评审，不做「写进规范却无从检查」的规则。
- **离线自足**：权威来源原文快照内置，引用校验不需要联网。
- **格式与逻辑分离**：工具格式化只做 lint 检查，禁止自动改写源码；人工排版与工具排版同等有效。

覆盖命名、格式、注释与文档、语言与并发、常量与魔法值、体量上限、**17 类缺陷检测**、
基线采集与五批迁移，以及既有代码的**完整整改流程**（格式化 + 命名 + 文档 + 语言约束全部到位才算完成）。

## 安装

### WorkBuddy（桌面端）

1. 侧边栏进入**插件管理** → **添加市场**。
2. 在「市场来源」里填 `pluginsWriter/swift-coding-standards`，提交。
3. 在市场里找到 **swift-coding-standards**，点**安装**，选择作用域（装给你自己选 user，只给本仓库选 project）。
4. 装完确认列表中出现该插件并处于启用状态。

### WorkBuddy（终端 TUI）

```
/plugin marketplace add pluginsWriter/swift-coding-standards
/plugin validate ./plugins/swift-coding-standards
/plugin install swift-coding-standards@swift-standards
/reload-plugins
```

装完**不要只看命令回显**，去确认快照真的落地了：

```sh
ls ~/.workbuddy/plugins/cache/swift-standards/swift-coding-standards/
```

应当能看到以版本号命名的目录，且里面有 `SKILL.md`。

### 其它 agent（Codex / Claude Code / opencode）

这些客户端直接按目录发现 skill，把本目录链到它们的 skill 根目录即可：

```sh
ln -sfn /Users/ugreen/Desktop/Application/swift-coding-standards/plugins/swift-coding-standards \
        ~/.agents/skills/swift-coding-standards
```

各客户端会读取的位置（opencode 会读全部三类）：

| 客户端 | 全局路径 |
| --- | --- |
| Codex | `~/.agents/skills/<名称>/SKILL.md` |
| Claude Code | `~/.claude/skills/<名称>/SKILL.md` |
| opencode | `~/.config/opencode/skills/<名称>/SKILL.md`、`~/.claude/skills/…`、`~/.agents/skills/…` |

目录名必须与 `SKILL.md` 里的 `name` 一致（都是 `swift-coding-standards`）。

## 用法

规范本身不需要调用。三条自检脚本按需手动跑：

```sh
SKILL=/Users/ugreen/Desktop/Application/swift-coding-standards/plugins/swift-coding-standards

bash "$SKILL/scripts/verify_consistency.sh" --strict   # 内部一致性（副本是否漂移）
bash "$SKILL/scripts/verify_citations.sh"              # 引文与快照双向校验（纯离线）
bash "$SKILL/scripts/verify_member_spacing.sh" --check # 成员之间缺空行（只读）
```

整改存量工程与刷新权威来源快照见 `references/remediation-playbook.md`
与 `scripts/fetch_official_sources.sh --help`。

## 目录结构

| 路径 | 内容 |
| --- | --- |
| `SKILL.md` | 入口：默认生效声明、高频规则、场景索引、终检清单 |
| `references/swift-coding-standards.md` | 规范正文（含版本表与附录 C 变更记录） |
| `references/remediation-playbook.md` | 整改手册：9 条验收标准与分批流程 |
| `references/defect-catalog.md` | 17 类缺陷全景（含可检查性与检测手段） |
| `references/naming-antipatterns.md` | 命名词典；**第 0 节是可接受词表的唯一权威** |
| `references/comment-standards.md` | 文档注释规范 |
| `references/official/` | 权威来源的逐字原文快照 + 来源登记（见下「许可」） |
| `assets/` | `.swift-format` 与 `.swiftlint.yml` 模板 |
| `scripts/` | 三个自检脚本 + 整改/引导/快照刷新脚本 |

## 许可与第三方内容

- 本插件的**原创内容**（`SKILL.md`、`scripts/`、`assets/`、本文件、`references/` 下除 `official/` 外的各篇）
  以 **MIT** 许可发布，全文见 `LICENSE`。
- **`references/official/` 是例外**：那里是上游权威来源的逐字原文快照，版权归原作者所有，
  分别适用 Apache License 2.0（S1/S3/S4/S5，全文见 `LICENSES/Apache-2.0.txt`）
  与 CC BY 4.0（S6，见 <https://creativecommons.org/licenses/by/4.0/legalcode>）。
- 完整署名、来源地址与再分发条件见 `THIRD-PARTY-NOTICES.md`。

## 版本

版本号以 `references/swift-coding-standards.md` 的**版本表与附录 C 变更记录**为唯一权威，
`plugin.json` 与市场清单的 `version` 必须与之一致 —— 三处一致由
`scripts/verify_consistency.sh` 第 9 节机器校验，改版本时须同时改。
（本文件刻意不写具体版本号，避免多出一处漂移源。）
