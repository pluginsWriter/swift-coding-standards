# swift-coding-standards

所有 Swift 工程的**默认编码规范与强制工具链**（swift-format + SwiftLint）。

仓库根目录就是这个 skill 本身：`SKILL.md` 在根，规范正文在 `references/`，脚本在 `scripts/`，
配置模板在 `assets/`。安装方式只有一种 —— 把本目录链接（或复制）到各客户端的 skill 根目录。

## 它解决什么问题

AI 写的 Swift 通常「能编译、功能对」，问题都出在没人检查的那部分：结构越堆越大、注释看着像但没有信息、
每一轮会话的排版都不一样。下表每一行都在真实工程里检出并计量过，并配了可直接跑的检测命令。

| AI 写代码的典型结果 | 具体表现 | 本 skill 的处置 | 机器可查 |
| --- | --- | --- | --- |
| **越堆越像屎山** | 单个类型几百行、函数上百行、圈复杂度 40+、参数一长串、嵌套好几层 | 硬阈值：类型体 300 行 / 函数体 60 行 / 圈复杂度 15 / 参数 6 个 / 行长 120 列；验收要求 `--strict`，warning 即失败 | 是 |
| **注释写了等于没写** | `// 初始化` 这类复述代码；公开 API 干脆没注释；中文工程里混进整段英文注释 | `references/comment-standards.md` 要求注释回答「为什么 / 契约 / 陷阱」；注释语言按项目既有约定（无约定默认中文）；**正文注释复核**是第 10 条验收标准 | 部分（`missing_docs` 只判有无，语言与内容需人工复核） |
| **风格每轮会话都在飘** | 同一工程 2/4 空格混排、成员之间空行时有时无、断行随机 | 固定 `.swift-format` + `.swiftlint.yml` 模板；**成员间空行** swift-format 与 SwiftLint 都没有对应规则，附自研 `verify_member_spacing.sh` | 是 |
| **新建文件没有文件头** | 头部整块缺失，或只留旧式两行注释 | 4.10「八行三段」标准头 + `verify_file_header.sh`；`assets/IDETemplateMacros.plist` 让 Xcode 新建文件自带 | 是 |
| **编造看着合理的内容** | 作者栏填「项目名 Team」、日期填当天、补注释时顺手生成一句假的文件作用 | 文件头**查结构不查值**，创建者默认拦截由项目名拼造的作者；`--fix` 只补结构、「文件作用」永远留 `TODO`，绝不代写内容 | 是 |
| **「跑过格式化 = 改完了」** | 只重排格式就宣称整改完成，命名、文档、魔法值一处没动 | 10 条验收标准 + 完成前自检门禁：机器项要命令输出，工具查不到的要给出复核范围与结论 | 靠流程强制 |
| **存量代码不敢动** | 一改就是上千行 diff，逻辑改动和格式改动混在同一个提交里 | `scripts/remediate.sh` 按管线跑：采基线 → 机械修复 → 复检 → 待办清单 → 报告；存量工程按正文 8.2 的五批推进，三类改动必须拆提交 | 是（管线） |
| **命名靠猜** | 生僻词 `reify` / `thunk`、自造缩写 `aniDur`、55 字符的常量名 | 判据只有一条：**遮住定义只看调用点，陌生人能否说出这行在做什么**。`normalize` / `perform` / `u16` 这类常用词明确可接受，不制造无意义重命名 | 部分 |
| **引用规范时编造出处** | 声称「官方指南要求……」，原文并没有那句 | 权威来源原文快照随包内置，`scripts/verify_citations.sh` 双向逐字校验：登记的引文必须能在快照里逐字检索到，正文新增的斜体引文必须已登记 | 是 |

其余缺陷类别（强制解包族、一行塞多语句、花括号换行、魔法字符串、无标签关联值、成员多于 3 的元组等）
合起来构成 **18 类缺陷全景**，每类的检测命令与整改动作见 `references/defect-catalog.md`。

核心特征：**默认生效**（涉及 Swift 代码即适用，无需点名）、**判据优先于清单**（只治读不懂，不治不眼熟）、
**约束力 ≈ 可检查性**（每条规则标注能否机器检出）、**离线自足**（引用校验不联网）、
**格式与逻辑分离**（工具只做 lint 检查，不自动改写源码；人工排版与工具排版同等有效）。

## 装完先跑这四条

前两条是 Swift 工具链自带命令，后两条是本 skill 的自研检测器 —— **成员间空行与文件头这两条规则
两类工具都查不出**，只能靠后两条。四条全部只读，不改源码。

```bash
SKILL=/path/to/swift-coding-standards     # 本仓库根目录（含 SKILL.md 的那一层）
PROJ=/path/to/your-swift-project          # 你的 Swift 工程根目录
DIRS="Sources Tests"                      # 工程里的源码目录，Xcode 工程按实际填，可多个
cd "$PROJ"

swift format lint --recursive --strict $DIRS                      # 期望无输出
swiftlint lint --strict --quiet                                   # 期望无输出（务必带 --strict）
bash "$SKILL/scripts/verify_member_spacing.sh" "$PROJ" --check    # 成员之间缺空行
bash "$SKILL/scripts/verify_file_header.sh" "$PROJ" --check       # 文件头八行三段结构
```

两个脚本的参数顺序是「目录在前、开关在后」，目录不可省，否则以用法错误退出；
`--copyright "主体"` 才严校版权行。所有脚本都支持 `-h`。

> `swift format lint` 的违规输出走 **stderr**，且同一条会重复输出约 3.5 倍 ——
> 重定向到 `/dev/null` 或不去重都会得到「零违规」的假结论。这类计数陷阱写在 `references/defect-catalog.md`。

要一次性拿到全部类别的数量、待办清单与整改报告：

```bash
bash "$SKILL/scripts/remediate.sh" "$PROJ" --check   # 不改源码；缺配置时只新增模板
bash "$SKILL/scripts/remediate.sh" "$PROJ" --fix     # 会修改源码，先在干净提交上操作
```

## 覆盖范围

命名、格式、注释与文档、语言与并发、常量与魔法值、体量上限、错误处理、测试、文件级要求（含文件头）、
迁移与整改流程。规范正文是 `references/swift-coding-standards.md`，每条规则标明 MUST / SHOULD / 允许项
与能否机器检出；整改存量工程按 `references/remediation-playbook.md` 执行（10 条验收标准 + 整改顺序）。

## 安装

各客户端都按「skill 根目录下的同名子目录」发现 skill，所以安装就是一条软链。链接名必须与
`SKILL.md` 里的 `name` 一致（`swift-coding-standards`，kebab-case）。

```sh
git clone https://github.com/pluginsWriter/swift-coding-standards
cd swift-coding-standards

mkdir -p ~/.workbuddy/skills ~/.agents/skills ~/.claude/skills
ln -sfn "$PWD" ~/.workbuddy/skills/swift-coding-standards   # WorkBuddy 桌面端
ln -sfn "$PWD" ~/.agents/skills/swift-coding-standards      # Codex / dsh / Qoder（三者都扫这里）
ln -sfn "$PWD" ~/.claude/skills/swift-coding-standards      # Claude Code
```

装完**重启客户端**（技能清单在会话启动时加载），在可用技能里确认出现 `swift-coding-standards`。
之后 `git pull` 即更新，软链不用重建。

| 客户端 | skill 根目录 | 依据 |
| --- | --- | --- |
| WorkBuddy 桌面端 | `~/.workbuddy/skills/` | 本机实测：跟随软链；技能搜索只覆盖官方市场，第三方仓库需这样装 |
| Codex | `~/.agents/skills/` | Agent Skills 通用根目录 |
| Claude Code | `~/.claude/skills/` | 同上 |
| opencode | 自动加载 `~/.agents/skills` 与 `~/.claude/skills` | 本机实测（`opencode debug skill`）：上面两条链建好后无需额外操作 |
| Qoder | `~/.agents/skills`；也可用 `~/.qoder-cn/skills/` | 本机实测：只存在于 `~/.agents/skills` 的技能同样出现在可用技能列表；`~/.qoder-cn/skills/` 内的软链同样被跟随 |
| dsh | `~/.agents/skills/` 或 `~/.dsh/skills/` | 官方文档 `@deepseek-ai/dsh-skill-filesystem`：rank 500 扫 `~/.agents/skills`、rank 400 扫 `~/.dsh/skills`，默认跟随软链；项目级 `<repo>/.agents/skills`、`<repo>/.dsh/skills` 优先级更高 |
| zcode | `~/.zcode/skills/` | 本机观察：该目录现有条目全部是指向 `~/.agents/skills/<name>` 的软链，未见它自动扫描的证据，因此单独建一条链 |

zcode 需要单独建链（用相对路径与现有条目保持一致）：

```sh
mkdir -p ~/.zcode/skills
ln -sfn ../../.agents/skills/swift-coding-standards ~/.zcode/skills/swift-coding-standards
```

不想用软链的话，把整个目录 `cp -R` 过去效果相同，只是更新要重新拷贝。

## 许可

- 本 skill 的**原创内容**（`SKILL.md`、`scripts/`、`assets/`、`README.md`、`references/` 下除 `official/`
  外的各篇）以 **MIT** 许可发布，全文见 [`LICENSE`](LICENSE)。
- **`references/official/` 是例外**：那里是上游权威来源的逐字原文快照，版权归原作者所有，
  分别适用 Apache License 2.0（S1/S3/S4/S5，全文见 `LICENSES/Apache-2.0.txt`）
  与 CC BY 4.0（S6，见 <https://creativecommons.org/licenses/by/4.0/legalcode>）。
- 完整署名、来源地址与再分发条件见 [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md)。

## 版本

版本号以 `references/swift-coding-standards.md` 的**版本表与附录 C 版本一览**为唯一权威，两处一致由
`scripts/verify_consistency.sh` 第 2 节机器校验，改版本时须同时改。
（本文件刻意不写具体版本号，避免多出一处漂移源。）
