# 把 swift-coding-standards 发布为插件 —— 路径、判据与待裁决项

日期：2026-09-18 ｜ 状态：**方案已定，未落盘**（本轮未改动任何发布内容）

---

## 0. 结论先行

1. **可行，且不需要产生第二份副本。** 插件加载器显式接受「`SKILL.md` 就在插件根目录」这种形态，所以正身可以原地变成插件，不必把内容复制到别的仓库。
2. **必须新增的只有 2 个 JSON 清单**（`plugin.json` + `marketplace.json`），外加 `README.md`；`LICENSE` 取决于分发范围。
3. **真正的岔路只有一条**：插件**根目录放哪**。这决定要不要搬动文件、要不要重指三条软链。见第 3 节。
4. **一个必须知道的限制**：`/plugin`、`/reload-plugins`、`/plugin-validate` 在 WorkBuddy 桌面端是 **终端 TUI 专属**，桌面界面里执行会直接回一句「命令 X 仅在终端 TUI 中可用」。所以装插件这件事要么在终端里做，要么走桌面端的插件管理界面（后者本轮未取证）。

---

## 1. 硬证据（读的是加载器代码，不是文档推测）

| # | 事实 | 证据来源 | 意义 |
| --- | --- | --- | --- |
| 1 | 清单目录名**三个都认**：`.codebuddy-plugin` / `.workbuddy-plugin` / `.claude-plugin` | `cli/dist/codebuddy.js`：`ev=[".codebuddy-plugin",".workbuddy-plugin",".claude-plugin"]` | 用 `.codebuddy-plugin` 最稳（两个内置市场都用它） |
| 2 | 插件**允许把 `SKILL.md` 放在插件根**，不强制 `skills/<名>/SKILL.md` | `SkillExtensionLoader.load()`：读取完清单声明的 skills 路径后，还会 `join(pluginRoot,"skills")` 扫描，**并且**单独 `join(pluginRoot,"SKILL.md")` 解析 | **这是「零搬动」方案成立的全部依据** |
| 3 | 市场清单固定位置 `.codebuddy-plugin/marketplace.json` | `codebuddy-plugins-official`、`workbuddy-builtin` 两个市场实测 | 位置不可自选 |
| 4 | 插件清单固定位置 `.codebuddy-plugin/plugin.json` | 同上 + `prompt-common/.workbuddy-plugin/plugin.json` | 同上 |
| 5 | 安装标识是 `插件名@市场名` | `installed_plugins.json` 的键形如 `welcomemode-code@workbuddy-builtin` | 市场名取 `marketplace.json` 的 `name` 字段 |
| 6 | 可用命令：`/plugin marketplace add`、`/plugin install <名>@<市场>`、`/reload-plugins`、`/plugin-validate [路径]` | 命令表注册项 | 有官方校验命令可自测 |
| 7 | `/plugin`、`/reload-plugins`、`/plugin-validate`、`/agents` 等在桌面端被拦 | 代码：`命令 ${name} 仅在终端 TUI 中可用` | 见结论 4 |
| 8 | 插件里的 skill，`description` 会被自动追加 `(插件名)` | `SkillLoader`：`eI.includes(eB)||(eI=\`${eI} ${eB}\`)` | 不影响触发，但市场里看到的名字带后缀 |
| 9 | 版本比较按**声明版本**做不可变语义；同版本视为 up-to-date 不重写 cache | 官方 `plugin-marketplaces.md` | 每次发布**必须**递增版本号，否则别人装到的是旧的 |

官方文档（权威，本轮已核对）：
- `plugins.md` — 插件系统概述 <https://cnb.cool/codebuddy/codebuddy-code/-/git/raw/main/docs/plugins.md>
- `plugin-marketplaces.md` — 市场规范与发布 <https://cnb.cool/codebuddy/codebuddy-code/-/git/raw/main/docs/plugin-marketplaces.md>
- `plugins-reference.md` — 完整字段参考 <https://cnb.cool/codebuddy/codebuddy-code/-/git/raw/main/docs/plugins-reference.md>

---

## 2. 本 skill 的现状体检（好消息：几乎不用改）

| 检查项 | 结果 |
| --- | --- |
| 内容里有绝对路径 / `~/` / `$HOME` / `.workbuddy` 引用 | **0 处命中** —— 完全可移植 |
| 脚本定位自身目录的方式 | 6 个脚本全部 `cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd`，**天然可重定位** |
| macOS 专属命令（`stat -f`、`sed -i ''`、`pbcopy`、`osascript`） | **0 处命中** |
| 全部脚本 shebang | 统一 `#!/usr/bin/env bash` |
| 打包排除项 | `.gitignore` 已排除 `.workbuddy/` 与 `.DS_Store`，**实测 `git check-ignore` 生效** |
| 缺什么 | `README.md`、`LICENSE`、两个 JSON 清单 |

**结论：`README.md` + `LICENSE` + 2 个 JSON 就是全部工作量。** 内容主体一行都不用改。

---

## 3. 唯一岔路：插件根放哪（二选一）

### 方案 A —— 零搬动：插件根 = 仓库根 = 现在的正身

```
swift-coding-standards/                     ← 正身，一个文件都不挪
├── .codebuddy-plugin/
│   ├── plugin.json                         ← 新增：插件清单
│   └── marketplace.json                    ← 新增：市场清单，source 指向本仓库自身
├── SKILL.md                                ← 保持原位（依据证据 #2）
├── references/  assets/  scripts/
├── README.md                               ← 新增
└── LICENSE                                 ← 待定
```

- **优点**：改动最小；三条软链（`~/.agents` / `~/.workbuddy` / `~/.claude`）**完全不用动**，agent 侧发现路径零风险。
- **代价**：市场清单里的 `source` 要写成自引用 GitHub 仓库（`{"source":"github","repo":"OWNER/REPO"}`）。**「source 支持 GitHub 仓库」是官方明确写了的**，但「市场与被指向的插件是同一个仓库」这种自引用形态**本轮无法实测**（本机没有远端仓库可验）。
- **另一个代价**：纯本地安装（不联远端）走不通 —— 本地目录市场需要插件在子目录里用相对路径引用。

### 方案 B —— 规范形态：仓库根做市场，插件放进 `plugins/` 子目录

```
swift-coding-standards/                          ← 仓库 / 工作空间根
├── .codebuddy-plugin/
│   └── marketplace.json                         ← 新增：source 写相对路径 "./plugins/..."
├── plugins/
│   └── swift-coding-standards/                  ← 插件根 = skill 根
│       ├── .codebuddy-plugin/plugin.json        ← 新增
│       ├── SKILL.md
│       ├── references/  assets/  scripts/
│       ├── README.md
│       └── LICENSE
└── README.md
```

- **优点**：与 `codebuddy-plugins-official`、`workbuddy-builtin` 两个内置市场的形态**完全一致，零未知项**；本地目录与远端 Git 两种分发方式都支持；以后要加第二个插件直接放 `plugins/` 里。
- **代价**：要把 `SKILL.md` / `references` / `assets` / `scripts` 挪进子目录，并**重指三条软链**指向 `.../plugins/swift-coding-standards`。搬完必须重新验证一次 inode 同一性（`stat -L -f %i`）。

### 怎么选

| 你的目的 | 建议 |
| --- | --- |
| 只是自己本机用 | **不必做插件** —— 现有三条软链已经生效，做插件不带来额外能力 |
| 给团队 / 多人「装一下就能用」 | **方案 B** —— 形态规范、两种分发都通、无未知项 |
| 想先用最小改动跑通验证 | **方案 A** —— 之后要转 B 也只是搬一次目录 |

---

## 4. 两个新文件的确切内容

### 4.1 `.codebuddy-plugin/plugin.json`

```json
{
  "name": "swift-coding-standards",
  "version": "1.5.6",
  "description": "所有 Swift 工程的默认编码规范与强制工具链（swift-format + SwiftLint）：命名、格式、注释、语言与并发约束、体量上限、17 类缺陷检测与完整整改流程。",
  "author": {
    "name": "Jason Bourn"
  },
  "keywords": [
    "swift",
    "coding-standards",
    "conventions",
    "swift-format",
    "swiftlint",
    "code-review",
    "lint",
    "refactoring"
  ]
}
```

取值依据：
- `name` 必须匹配 `/^[A-Za-z0-9][-A-Za-z0-9._]*$/`（读自校验器 `iC`）—— 现名合法。
- `version` 必须能被 `/^\d+\.\d+\.\d+/` 匹配（读自校验器）—— 用 skill 当前版本 `1.5.6`。
- **`license` 故意不写**：许可未定，不猜。定了再加一行 `"license": "MIT"`（或 `"UNLICENSED"`）。

### 4.2 `.codebuddy-plugin/marketplace.json`

方案 B（推荐）的写法：

```json
{
  "name": "swift-standards",
  "description": "Swift 工程规范与工具链插件市场",
  "owner": {
    "name": "Jason Bourn"
  },
  "plugins": [
    {
      "name": "swift-coding-standards",
      "source": "./plugins/swift-coding-standards",
      "description": "所有 Swift 工程的默认编码规范与强制工具链（swift-format + SwiftLint）",
      "keywords": ["swift", "coding-standards", "lint", "swiftlint", "swift-format"]
    }
  ]
}
```

方案 A 只改 `source` 一行：

```json
      "source": { "source": "github", "repo": "OWNER/REPO" },
```

**刻意不在市场条目里写 `version`**：`version` 字段在市场条目里是可选的（官方字段表确认），不写就由 `plugin.json` 独占版本权威 —— 避免同一个版本号有两处出处而产生漂移（本工程「单一权威来源」纪律）。

---

## 5. 落地步骤（方案 B 版）

> 命令里的 `REPO` / `OWNER` 请替换成真实值后再执行；不要直接粘带尖括号的占位符，zsh 会把 `<` 当输入重定向报错。

**第 1 步 · 建目录并搬内容（同卷重命名，原子）**

```sh
P=/Users/ugreen/Desktop/Application/swift-coding-standards
mkdir -p "$P/.codebuddy-plugin" "$P/plugins/swift-coding-standards"
cd "$P"
mv SKILL.md references assets scripts plugins/swift-coding-standards/
```

**第 2 步 · 写两个清单 + README + LICENSE**（内容见第 4 节）

**第 3 步 · 重指三条软链**（关键：先确认没搬错，再换）

```sh
NEW=$P/plugins/swift-coding-standards
for L in ~/.agents/skills/swift-coding-standards \
         ~/.workbuddy/skills/swift-coding-standards \
         ~/.claude/skills/swift-coding-standards; do
  echo "$L -> $(readlink "$L")"
done
# 核对无误后逐条重指：
ln -sfn "$NEW" ~/.agents/skills/swift-coding-standards
ln -sfn "$NEW" ~/.workbuddy/skills/swift-coding-standards
ln -sfn "$NEW" ~/.claude/skills/swift-coding-standards
```

**第 4 步 · 验证（三条都要过，不能只看退出码）**

```sh
# 4a 穿透软链后必须与正身同一 inode
stat -L -f %i "$NEW"
stat -L -f %i ~/.agents/skills/swift-coding-standards
# 4b 两条自检基线必须仍是 FAIL 0 / WARN 0、引文全通过
"$NEW/scripts/verify_consistency.sh" --strict
"$NEW/scripts/verify_citations.sh"
# 4c skill 仍能被 agent 发现（Codex 权威手段）
codex debug prompt-input 2>/dev/null | grep -n "swift-coding-standards"
```

**第 5 步 · 装进 WorkBuddy 并验证被加载**

终端 TUI 内执行（桌面端会被拦）：

```
/plugin marketplace add /Users/ugreen/Desktop/Application/swift-coding-standards
/plugin validate /Users/ugreen/Desktop/Application/swift-coding-standards/plugins/swift-coding-standards
/plugin install swift-coding-standards@swift-standards
/reload-plugins
```

装完确认 `~/.workbuddy/plugins/cache/swift-standards/swift-coding-standards/1.5.6/` 下**真的出现了 SKILL.md**（核验副作用，不看提示信息）。

---

## 6. 已知风险与待实测项（不要当成已验证）

| 项 | 状态 |
| --- | --- |
| 插件与个人软链**同时存在**会怎样 | **未实测**。两者都在扫描范围内，可能同一 skill 被注册两次。建议发布后二选一，别两个都留 |
| 方案 A 的「市场与被指向插件同一仓库」自引用 | **未实测**（本机无远端仓库）。“source 支持 GitHub 仓库”本身是官方明确的 |
| 本地源（`"source":"local"`）的确切字段名 | **未取证**。官方文档只给了相对路径写法 `"./plugins/xxx"`，所以纯本地安装请用方案 B |
| 桌面端的插件管理界面能否完成安装 | **未取证**。已确证的只是 `/plugin` 系列命令在桌面端被拦 |
| `description` 被追加 `(swift-coding-standards)` | 代码已证，**不影响触发**，仅市场显示带后缀 |
| 私有仓库 / 受限许可分发 | 需 git 鉴权；`LICENSE` 未定前不要公开发布 |

---

## 7. 建议顺带做的一条防漂移校验（可选，但符合本工程纪律）

`plugin.json` 的 `version` 与 skill 版本是**第二处版本出处**，天然是漂移源。可仿照现有 `verify_consistency.sh` 加一条只读校验：`plugin.json.version` 必须等于被发布 skill 的当前版本号，不等就 FAIL。

**建议先不加脚本**（避免规则膨胀），等真的开始按版本发布时再加 —— 这与「不允许存在『写进规范但没有任何检查手段』的规则」是同一枚硬币的两面：要么现在就加检查，要么先别写进规范。

---

## 8. 需要你裁决

1. **分发范围**：只自己本机 / 团队私有仓库 / 公开？→ 决定方案 A 还是 B，以及要不要 `LICENSE`。
2. **选 A 还是 B**（第 3 节）。
3. **许可证**（若对外）。
4. **是否接受 `/plugin` 系列在桌面端不可用**，安装动作改到终端 TUI 执行。
5. **是否现在就加第 7 节那条版本一致性校验。**
