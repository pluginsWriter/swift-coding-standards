# swift-coding-standards —— 项目长期备忘

> 2026-09-14 从旧工作空间 `~/Desktop/skill-lab` 迁入（旧处同名文件已冻结，只维护这一份）。

## 这个工程是什么

**工作空间 = 插件市场根；skill 正身在其下的 `plugins/swift-coding-standards/`。**
「本工程」= `swift-coding-standards` skill 的内容本身，唯一产物就是这些文件。
2026-09-18 从「仓库根即 skill 根」改为「市场根 + 插件子目录」（理由与证据见
`.workbuddy/notes/plugin-release-2026-09-18.md`）；原会话来龙去脉见 `.workbuddy/memory/原会话纪要.md`。

## 路径拓扑（一份正身 + 三条软链）

```
~/Desktop/Application/swift-coding-standards/plugins/swift-coding-standards ← 正身，改这里
~/.agents/skills/swift-coding-standards      → 绝对 → 正身（Codex 的根目录，别名 r1）
~/.workbuddy/skills/swift-coding-standards   → ../../.agents/skills/…（WorkBuddy）
~/.claude/skills/swift-coding-standards      → ../../.agents/skills/…（Claude Code）
```

一条绝对锚点 + 两条相对跟随：迁移仓库只需改 `~/.agents` 那条。三条穿透后同一 inode
（`stat -L -f %i`，2026-09-18 = `28288554`），不是副本，编辑任意一条都落到同一份文件。

- **opencode 不需要单独建链**（2026-09-18 实测）：它自动加载 `~/.agents/skills` 与
  `~/.claude/skills`；本机原先建的 `~/.config/opencode/skills/…` 属冗余，**已删除**。
- **WorkBuddy 只扫 `~/.workbuddy/skills/`**（CLI 对 `.agents` 零引用，`.claude` 仅用于 IDE 锁文件）。
  若在 WorkBuddy 装了插件，只需摘 `~/.workbuddy/skills/swift-coding-standards` 一条即可避免重复注册。
- **Codex 无需配置**：其 skill 根目录表直接含 `~/.agents/skills`（别名 `r1`），软链也认 →
  别在 `~/.codex/skills/` 下另建链接或副本。
- 正身不放回 `~/.agents/skills/` 的理由：那是隐藏目录，Finder 里难导航。
- 历史教训：2026-09-11 / 09-14 各出现一次**真目录副本**（逐字节一致但 inode 不同）——
  在其中编辑**不进加载链**，是无报错的静默分叉。`[ -L <路径> ]` 为假即说明它已是副本。
  `mv` 换方向前必须确认**同卷**（同卷是原子重命名，跨卷才是真拷贝）。

**看某个 agent 到底认不认这个 skill，用它自己的权威手段（换布局后必重跑）：**

- Codex：`codex debug prompt-input`（导出模型侧实际看到的 `### Available skills`）
- opencode：`opencode debug skill`（列全部已发现 skill 及其来源路径）

## 当前状态（2026-09-18）

- 版本 **v1.6.0**（2026-10-20）；插件内 28 个文件
- 市场根：`.codebuddy-plugin/marketplace.json` ／ `README.md` ／ `LICENSE` ／ `plugins/…`
- 插件根（= 正身）：`SKILL.md` ／ `references/`（含 `references/official/` 上游快照）／
  `assets/` ／ `scripts/` ／ `.codebuddy-plugin/plugin.json` ／ `README.md` ／ `LICENSE` ／
  `LICENSES/Apache-2.0.txt` ／ `THIRD-PARTY-NOTICES.md`
- 自检基线：`verify_consistency.sh --strict`（共 **10 节**）→ FAIL 0 / WARN 0；
  `verify_citations.sh` → 18 通过 0 失败
- 缺陷全景 **18 类**。第 17 类「成员间缺分隔空行」与第 18 类「文件头缺失或不合规」（正文 4.10）的检测器分别是 `scripts/verify_member_spacing.sh` 与 `scripts/verify_file_header.sh`
  —— 它是唯一的自研检测器，因为 swift-format 与 SwiftLint **都查不出**这条规则
- 已公开发布：`github.com/pluginsWriter/swift-coding-standards`（PUBLIC），市场名 `swift-standards`，
  插件标识 `swift-coding-standards@swift-standards`
- **版本号四处同时改**：正文版本表 ／ 附录 C 变更行 ／ `plugin.json` ／ 市场条目 —— 第 9 节机器校验
- 第 10 节看「文档命令可照抄性」（代码块与脚本示例里不得有**未加引号**的尖括号占位符）；
  `references/official/` 整目录跳过（上游逐字原文，不得改）

## 改 skill 时的硬规矩

**编辑与核验**

1. **同文件串行编辑**。并行 Edit 会「报成功但未落盘」；改完用 grep 逐一核验。
2. **核验副作用，不核验退出码**。`git apply` 在仓库根高于代码目录时会静默跳过（只打印
   `Skipped patch` 却**返回 0、文件不变**）；`patch`/`git apply` 的输出与退出码都不证明写入成功。
   只看副作用（文件内容、检测器数字）。写操作还可能被沙箱静默拦掉，必要时提权重跑。
3. **有副作用的命令一次只执行一次**。别在同一条 shell 里既 `cmd | tail` 又 `$(cmd)` 计数（等于跑两遍），
   用变量缓存输出再加工。**`git checkout -- <file>` 会连同未提交的修复一起丢掉**（2026-09-18 踩过：
   本想撤掉测试注入，结果把本轮自己的修复也撤了）—— 注入测试前先备份，或改用可逆的注入手法。
4. **校验函数本身也要被校验**。报「不一致」时先反问测量方法是否成立：
   - 2026-09-14 自查指纹把**绝对路径**也哈希了进去，A/B 必然不同，差点据此「停止执行」。
     正确：`( cd "$d" && find . -type f | sort | xargs shasum -a 256 ) | shasum -a 256`。
   - `stat -f %i` **不穿透软链**，比同一性必须用 `stat -L -f %i`。
   - 测「检测器是否真会报」时，先确认正例本身是正例（判据要求「上一个代码行是**独立成行**的 `}`」，
     样例写成单行 `func f() {}` 就永远命中不了）。
   - 新增机器校验后做**反向测试**：注入违规 → 必须 FAIL；合法形态（如加引号）→ 必须通过；
     还原后哈希逐字节一致。

**测量陷阱（macOS / zsh）**

5. **测退出码不要接管道，且 zsh 没有 `PIPESTATUS`**。`bash x.sh | tail -3; echo $?` 读到的是 `tail`
   的状态；`PIPESTATUS` 是 bash 的数组，zsh 里叫 `pipestatus`（小写、1 起），写 `${PIPESTATUS[0]}`
   会得到**空字符串**，看起来像「没报错」。正确写法：`OUT=$(bash x.sh 2>&1); RC=$?`。
6. **大输出不要经管道采集**。`opencode debug skill | grep` 会因 SIGPIPE 被**随机截断**，同一条件
   连测三次得到 0/1/0 的矛盾结果（2026-09-18 因此一度误判「删软链导致 opencode 看不到 skill」）；
   重定向到文件再分析即稳定可复现（三次均 290 行 / 48 个 skill）。与第 5 条同族。
7. **字符交替一律用 `grep -E`**。BSD grep 不支持 BRE 的 `\|`（GNU 扩展），`grep "a\|b"` 会静默
   退化成搜字面量 `a|b`、**无输出**，极易误判成「文件里没有」。

**文档与发布**

8. **发布内容里禁止出现本机绝对路径**（`/Users/ugreen/...`）。正确写法：clone 后自定位
   （`cd` → `ln -sfn "$PWD"`），或先定义变量再用 `"$VAR"`。自查：
   `grep -rnE "/Users/|~/Desktop|/opt/homebrew"` 对发布内容应为空。
9. **命令块里禁止未加引号的尖括号占位符**。zsh 把 `<` 当输入重定向，照抄直接
   `parse error near '<'`。改用「先定义变量再引用」（`P="…"` 再 `"$P"`；列表变量**有意不加引号**
   以便按空格拆成多个参数），或写真实路径。**普查口径要先定对**：只扫 `.md` 会漏掉 `scripts/`
   里的示例注释（它们会随 `--help` 打印给使用者）；`references/official/` 内的**一律不得改**。
10. **文档里写出的每条命令都要实跑一遍，正反两面都测**（脚本是 CLI 的唯一权威）。2026-09-18 一次
    抓到三条照抄必失败的：① `verify_member_spacing.sh --check` —— 该脚本**至少需要一个目录参数**，
    无参退出 2；② `fetch_official_sources.sh --help` —— 曾是六个脚本里**唯一不认 `--help`** 的
    （现已补）；③ `/plugin validate <path>` 默认你在仓库根。改完脚本，凡文档写出的调用方式
    （裸目录 / `--check` / `--quiet` / `--fix` 各种组合与参数顺序）都要实跑。
11. **不跨文件复制词表 / 阈值**。可接受词表的唯一权威是 `references/naming-antipatterns.md` 第 0 节，
    其余位置一律引用（`drain` 漂移即源于此）。
12. **配置联动必须一致**：`.swift-format` 的 `indentation.spaces = 4`、`lineLength = 120`、
    `indentSwitchCaseLabels = true`、`indentConditionalCompilationBlocks = true`，与
    `.swiftlint.yml` 的 `line_length.warning = 120` —— 五者必须始终一致。

**改完必做**

13. **跑自检**，不靠肉眼：`verify_consistency.sh --strict` + `verify_citations.sh`（不接管道看退出码）。
14. **递增版本时四处同时改**（见「当前状态」末两条）。加载器按**声明版本**做不可变语义，
    同版本视为 up-to-date 不重写 cache —— 不改版本，别人装到的仍是旧版。
15. **改前先看 `.workbuddy/memory/原会话纪要.md` 第 3 节**（用户既定硬约束），别把已推翻的决定翻回来。
16. **description 改动要重启 WorkBuddy 才影响自动触发**（启动时加载）；文件本身即时可读可跑。
17. **下「有没有某功能」的结论前，先查功能面板与 RPC 通道，不要只查命令注册表**。2026-09-18 因此
    翻过一次结论：只看到 `/plugin` 系列是 TUI-only 就断定「桌面端不能装插件」，后来在插件面板查到
    `plugin:addMarketplace` / `plugin:install` 等完整通道，桌面端其实可用（市场源还支持本机目录）。

## 已知边界

- 本工作空间**没有 Swift 代码**（只含 Markdown / 脚本 / JSON），skill 不会在这里自动触发 ——
  对「安静打磨」是好事。要验证触发需另建含 Swift 文件的目录。
- **记忆住在市场根的 `.workbuddy/`，不在插件内**（2026-09-18 起）：插件目录只有 26 个发布文件，
  开发笔记不可能随插件分发 —— 原先「打包必须排除 `.workbuddy/`」的隐患已由布局消除。
  实测也不影响两套自检。
- UGDockNative 的未提交改动（325 改 + 26 未跟踪）按用户要求保留在原 git 工作树，不受此处影响。
- **UGDockNative 真实路径与其 git 根不一致**：代码在
  `~/Desktop/Application/UgreenConnect/dock-center-macos/UGDockNative`，但 **git 仓库根是上一级**
  `dock-center-macos` → 打补丁用「代码目录内 `patch -p1 [-R]`」或「仓库根
  `git apply [-R] --directory=UGDockNative -p1`」。
- **成员空行整改的纯格式补丁留档**（仓库外，勿动勿删）：
  `~/Desktop/Application/UgreenConnect/format-patches/UGDockNative-member-spacing-703-2026-09-11.patch`
  （703 空行 / 91 文件；sha256 `003e7c69…0501c`）。它是「先把在制品单独提交」这条规矩在
  **顺序已颠倒**时唯一可用的拆分凭据。
