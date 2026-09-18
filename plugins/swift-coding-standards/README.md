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
/plugin install swift-coding-standards@swift-standards
/reload-plugins
```

（`/plugin validate` 是可选命令，校验本地的插件或市场清单；只在你已 clone 本仓库、且当前目录就是
仓库根时才用得上，例如 `/plugin validate ./plugins/swift-coding-standards`。）

装完**不要只看命令回显**，去确认快照真的落地了：

```sh
ls ~/.workbuddy/plugins/cache/swift-standards/swift-coding-standards/
```

应当能看到以版本号命名的目录，且里面有 `SKILL.md`。

### 其它 agent（Codex / Claude Code / opencode）

这些客户端按目录发现 skill。clone 本仓库后，把插件目录链到它们的 skill 根目录即可：

```sh
git clone https://github.com/pluginsWriter/swift-coding-standards
cd swift-coding-standards/plugins/swift-coding-standards

mkdir -p ~/.agents/skills ~/.claude/skills
ln -sfn "$PWD" ~/.agents/skills/swift-coding-standards   # Codex
ln -sfn "$PWD" ~/.claude/skills/swift-coding-standards   # Claude Code
```

| 客户端 | 全局路径 | 说明 |
| --- | --- | --- |
| Codex | `~/.agents/skills/swift-coding-standards/SKILL.md` | 需上面第一条链接 |
| Claude Code | `~/.claude/skills/swift-coding-standards/SKILL.md` | 需上面第二条链接 |
| opencode | `~/.config/opencode/skills/swift-coding-standards/SKILL.md` | 通常无需额外操作：opencode 会自动加载 `~/.agents/skills` 与 `~/.claude/skills`（即上面两处）；仅当你想装进它自己的目录时才用此路径 |

链接名必须与 `SKILL.md` 里的 `name` 一致（都是 `swift-coding-standards`）。

注意：用插件方式安装时，本地副本落在**带版本号的缓存目录**，升级后会换目录 —— 不要把缓存目录链给其它客户端，长期使用请用上面的 clone。

## 用法

规范本身不需要调用。自检脚本按需手动跑 —— 前两条检查**本 skill 自身**，在插件目录内执行：

```sh
bash scripts/verify_consistency.sh --strict   # 内部一致性（副本是否漂移）
bash scripts/verify_citations.sh              # 引文与快照双向校验（纯离线）
```

第三条检查**你的 Swift 工程**。参数顺序是「目录在前、开关在后」，目录不可省，否则会以用法错误退出：

```sh
PROJ=/path/to/your-swift-project
bash scripts/verify_member_spacing.sh "$PROJ" --check   # 成员之间缺空行（只读）
```

整改存量工程见 `references/remediation-playbook.md`。权威来源快照的状态查看与刷新见
`scripts/fetch_official_sources.sh` 的头部注释（`--status` 离线看状态、`--freshness` 联网比对上游、
`--check` 只查可达；**不带参数即重新抓取**）。

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
