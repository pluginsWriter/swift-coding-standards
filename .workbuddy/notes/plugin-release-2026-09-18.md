# swift-coding-standards 插件化发布 —— 执行记录

日期：2026-09-18 ｜ 状态：**已发布**
commit `8db82a7`，已推送 `origin/main`，仓库 PUBLIC（`pluginsWriter/swift-coding-standards`）。
前置方案见同目录 `plugin-packaging-2026-09-18.md`（当时为「未落盘」）。

用户 5 项裁决：**公开** ／ **方案 B** ／ **许可证由我制作** ／ **桌面端与 TUI 均要可用** ／ **现在就加版本一致性校验**。

## 0. 一句话结果

仓库改为「插件市场根 + 插件子目录」，插件已公开可安装；**正身没有第二份副本**；
四条 agent 软链重指后仍穿透同一 inode。

## 1. 结构（方案 B）

```
swift-coding-standards/                              ← 市场根（= 工作空间）
├── .codebuddy-plugin/marketplace.json               ← 新增：市场清单
├── README.md                                        ← 新增：仓库级索引
├── LICENSE                                          ← 新增：MIT
├── plugins/swift-coding-standards/                  ← 插件根 = skill 正身
│   ├── .codebuddy-plugin/plugin.json                ← 新增：插件清单
│   ├── SKILL.md  references/  assets/  scripts/
│   ├── README.md  LICENSE  THIRD-PARTY-NOTICES.md
│   └── LICENSES/Apache-2.0.txt
├── .gitignore  .git/  .workbuddy/                   ← 均留在市场根，不进插件
```

插件目录实测 **26 个文件 / 492K**，不含任何开发笔记 —— 原先「打包必须排除 `.workbuddy/`」
那条隐患从结构上消除了（它现在在市场根，不在插件内）。

## 2. 搬动的证据（不靠退出码）

- `git mv` 后 `git status` 显示 **21 条纯重命名（R，0 行变更）**
- 另做独立核验：搬动前后各生成「sha256 + 相对路径」清单，**内容哈希多重集完全一致**
- 路径映射的逐条比对只报一处差异：`.gitignore` 有意留在市场根。
  **是我的校验假设错了**（写成「全部搬走」），不是搬动错了 —— 记录在案以免下次误判
- 搬完两条自检基线仍为 FAIL 0 / WARN 0、引文 18 通过 0 失败

## 3. 新增一致性校验（第 9 节）与反向测试

`verify_consistency.sh` 新增第 9 节「发布清单」：插件名、**三处版本号**（正文版本表 /
`plugin.json` / 市场条目）、市场条目 `source`、两份 `LICENSE` 逐字节一致。
装进 `plugins/cache/` 后上层不再是仓库，相关检查转 `[note]` 跳过而非误报（不引入新 WARN）。

**反向测试 —— 证明它真的会拦，不只是会说 OK**：

| 故意改坏 | 结果 |
| --- | --- |
| `plugin.json` 版本 → 9.9.9 | FAIL 2（版本表不符 + 市场条目不符） |
| 插件根 `LICENSE` 追加一行 | FAIL 1（两份许可漂移） |

还原后 sha256 与改前逐字节一致，再跑回到 FAIL 0 / WARN 0。

## 4. 许可证取舍

**MIT**。理由：本工程是规范文本 + 检测脚本，不含可专利实现，Apache-2.0 的专利授权条款
无实际收益；规范要被人抄进自家 `CODING_STYLE.md`、企业要能无顾虑采纳，MIT 义务最轻。
若改选 Apache-2.0，只需替换两份 `LICENSE` 文本（第 9 节会校验两份同文）。

**公开发布必做、而原方案漏了的一步**：`references/official/` 是上游**逐字原文**，
其中 S1/S3/S4/S5 为 Apache-2.0 —— 其第 4(a) 条**要求随附许可全文**，原先只有来源登记表、
没有全文。已补：

- `LICENSES/Apache-2.0.txt` —— 全文取自本机官方插件的 `playwright-cli/LICENSE`（避免手抄出错），
  并核验无 Microsoft 残留填充值、五处关键条款齐全
- `THIRD-PARTY-NOTICES.md` —— 署名表 + 各源许可 + 本插件遵守的再分发条件
- CC BY 4.0（S6）按第 3(a)(1) 条以链接方式提供，未内置全文

## 5. 桌面端 / TUI 双通（用户第 4 项）

- **桌面端可用，且上一轮的结论是错的**：当时只查了斜杠命令表、没查插件面板，据此得出
  「安装只能在 TUI」。实际桌面端有完整插件管理 UI —— 文案 `plugins.addMarketplace`
  （"Add Marketplace"），`plugins.addMarketplace.sourceTip` 明确支持四种源：
  `owner/repo`(GitHub) / SSH / ZIP / `./path/to/marketplace`(Local)；
  RPC 通道 `plugin:addMarketplace`、`plugin:install`、`plugin:refreshMarketplace`；
  安装作用域有 user / project / local 三种。
- **TUI 可用**：`/plugin marketplace add` + `/plugin install` + `/reload-plugins`
- **Codex / Claude Code / opencode**：走 skill 目录发现，不依赖插件系统

## 6. 软链现状（四条，穿透同一 inode `28288554`）

```
~/.agents/skills/swift-coding-standards          → 绝对 → 正身（锚点）
~/.workbuddy/skills/swift-coding-standards       → ../../.agents/skills/…（WorkBuddy）
~/.claude/skills/swift-coding-standards          → ../../.agents/skills/…（Claude Code）
~/.config/opencode/skills/swift-coding-standards → ../../../.agents/skills/…（opencode，本轮新增）
```

拓扑保持既有设计：**一条绝对锚点 + 三条相对跟随**（迁移仓库只需改一条）。
中途一度拉平成四条绝对，已改回。

**新增证据**：WorkBuddy **只扫 `~/.workbuddy/skills/`** —— CLI 里对 `.agents` 零引用，
`.claude` 只出现在 IDE 锁文件路径（`.claude/ide`）。因此「软链与插件重复注册」的处置可精确到
**只摘 `~/.workbuddy/skills/swift-coding-standards` 一条**，其余三条留给 Codex / Claude Code / opencode。

## 7. 已知未修 / 待决

1. **尖括号占位符 20 处**（`<skill-dir>` / `<工程目录>` / `<dirs>` / `<module>`…），分布在：
   `SKILL.md:70,78,86,87,95,138,144,162,164`；`references/defect-catalog.md:10,38`；
   `references/remediation-playbook.md:15,63,73,91,96,103,179,181`；`references/swift-coding-standards.md:89`。
   照抄会被 zsh 当输入重定向报 `parse error`。属全库「先定义变量再引用」的约定变更，
   **本轮未改**（不与发布混作一个提交），只改了 `SOURCES.md` 那一处。
2. **双份注册未实测**：处置方案已定（见第 6 节），但「同时存在会怎样」仍未被实证。
   验证方式：装完插件后看会话里 `<available_skills>` 是否出现两条同名条目。
3. **桌面端 Local 源的字段形态未取证**：`./path/to/marketplace` 的实际解析规则没测过
   （本机无可交互桌面端）。走 GitHub 源 `pluginsWriter/swift-coding-standards` 是已证可行的路径。
4. 市场条目里 `version` 与 `plugin.json` 同写（与两个官方市场一致）本会产生第二处版本出处 ——
   已由第 9 节机器校验兜住，未选择「刻意省略」方案（那样得依赖未取证的加载器回退行为）。
