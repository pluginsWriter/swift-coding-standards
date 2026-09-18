# swift-coding-standards

所有 Swift 工程的默认编码规范与强制工具链（swift-format + SwiftLint）。

本仓库同时是**插件市场**，插件本体在 [`plugins/swift-coding-standards/`](plugins/swift-coding-standards/)。
安装、用法、目录说明与许可，见 [插件 README](plugins/swift-coding-standards/README.md)。

## 安装（两种入口）

**WorkBuddy 桌面端**：插件管理 → 添加市场 → 填 `pluginsWriter/swift-coding-standards` → 安装。

**WorkBuddy 终端 TUI**：

```
/plugin marketplace add pluginsWriter/swift-coding-standards
/plugin install swift-coding-standards@swift-standards
/reload-plugins
```

**其它 agent（Codex / Claude Code / opencode）**：把 `plugins/swift-coding-standards` 链到各自的 skill 目录，
例如 `ln -sfn "$PWD/plugins/swift-coding-standards" ~/.agents/skills/swift-coding-standards`。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `.codebuddy-plugin/marketplace.json` | 市场清单（本仓库作为市场） |
| `plugins/swift-coding-standards/` | 插件本体 = skill 本体 |
| `plugins/swift-coding-standards/.codebuddy-plugin/plugin.json` | 插件清单 |

## 许可

原创内容以 **MIT** 发布（见 [`LICENSE`](LICENSE)）。
`plugins/swift-coding-standards/references/official/` 存放的上游原文快照**不适用 MIT**，
分别适用 Apache License 2.0 与 CC BY 4.0，署名与再分发条件见
[`THIRD-PARTY-NOTICES.md`](plugins/swift-coding-standards/THIRD-PARTY-NOTICES.md)。
