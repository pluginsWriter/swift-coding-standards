#!/usr/bin/env bash
#
# bootstrap_swift_style.sh —— 把《Swift 编码规范》的强制工具链安装到任意 Swift 工程
#
# 行为：
#   1. 检测 swift format / swiftlint 是否可用
#   2. 安装 .swift-format 与 .swiftlint.yml（已存在则默认跳过，除非 --force）
#   3. 输出违规基线（按规则统计）
#   4. 仅在显式传入 --fix 时才修改源码
#
# 安全性：本脚本不会删除任何文件；除 --fix 外不会修改任何源码。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"

PROJECT_DIR=""
DIRS=""
MODE="check"
FORCE=0

usage() {
  cat <<'EOF'
用法: bootstrap_swift_style.sh [选项] [工程目录]

选项:
  --dirs "目录1 目录2"  Swift 源码目录，空格分隔（默认自动探测 Sources Tests，
                      若都不存在则用当前目录）
  --check             只检查并输出基线（默认行为）
  --fix               执行 swift format --in-place，会修改源码
  --force             覆盖工程内已存在的 .swift-format / .swiftlint.yml
  -h, --help          显示本帮助

示例:
  bootstrap_swift_style.sh                       # 检查当前目录
  bootstrap_swift_style.sh ~/code/MyApp --check  # 检查指定工程
  bootstrap_swift_style.sh ~/code/MyApp --fix    # 格式化指定工程
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dirs) DIRS="${2:-}"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --fix) MODE="fix"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知选项: $1" >&2; usage; exit 2 ;;
    *) PROJECT_DIR="$1"; shift ;;
  esac
done

if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(pwd)"
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "错误: 目录不存在 -> $PROJECT_DIR" >&2
  exit 2
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "工程目录: $PROJECT_DIR"

# ---------------------------------------------------------------- 工具检测
SWIFT_FORMAT_CMD=""
if swift format --version >/dev/null 2>&1; then
  SWIFT_FORMAT_CMD="swift format"
elif command -v swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT_CMD="swift-format"
fi

if [ -z "$SWIFT_FORMAT_CMD" ]; then
  echo "错误: 未找到 swift-format。Swift 6.x 工具链自带 'swift format'；" >&2
  echo "      旧工具链可执行: brew install swift-format" >&2
  exit 3
fi
echo "格式化器: $SWIFT_FORMAT_CMD ($($SWIFT_FORMAT_CMD --version))"

SWIFTLINT_OK=0
if command -v swiftlint >/dev/null 2>&1; then
  SWIFTLINT_OK=1
  echo "静态检查: swiftlint ($(swiftlint version))"
else
  echo "警告: 未找到 swiftlint，跳过语义检查。安装: brew install swiftlint" >&2
fi

# ---------------------------------------------------------------- 确定目录
if [ -z "$DIRS" ]; then
  for candidate in Sources Tests; do
    if [ -d "$PROJECT_DIR/$candidate" ]; then
      DIRS="$DIRS $candidate"
    fi
  done
  if [ -z "$DIRS" ]; then
    DIRS="."
  fi
fi
echo "检查目录:$DIRS"
echo

# ---------------------------------------------------------------- 安装配置
install_config() {
  local src="$1" dst="$2" label="$3"
  if [ ! -f "$ASSETS_DIR/$src" ]; then
    echo "警告: 模板缺失 -> $ASSETS_DIR/$src" >&2
    return 0
  fi
  if [ -f "$PROJECT_DIR/$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "跳过 $label: 已存在（--force 可覆盖）"
    return 0
  fi
  cp "$ASSETS_DIR/$src" "$PROJECT_DIR/$dst"
  echo "已安装 $label -> $dst"
}

install_config "swift-format.json" ".swift-format" ".swift-format"
install_config "swiftlint.yml" ".swiftlint.yml" ".swiftlint.yml"
echo

# ---------------------------------------------------------------- 基线统计
cd "$PROJECT_DIR"

echo "=== 格式违规（swift-format，前 10 类）==="
$SWIFT_FORMAT_CMD lint --recursive $DIRS 2>&1 \
  | grep -oE '\[[A-Za-z]+\]' | sort | uniq -c | sort -rn | head -10 || true
echo

if [ "$MODE" = "fix" ]; then
  echo "=== 执行自动修复（会修改源码）==="
  $SWIFT_FORMAT_CMD --in-place --recursive $DIRS
  echo "修复完成。"
  echo
  echo "=== 复检：格式 ==="
  remain=$($SWIFT_FORMAT_CMD lint --recursive $DIRS 2>&1 | grep -cE '\[[A-Za-z]+\]' || true)
  echo "剩余格式违规: ${remain:-0}"
  echo
fi

if [ "$SWIFTLINT_OK" -eq 1 ]; then
  echo "=== 语义违规（swiftlint，按规则统计）==="
  swiftlint lint --quiet --no-cache 2>&1 \
    | grep -oE '\([a-z_]+\)$' | sort | uniq -c | sort -rn || true
  echo
  echo "=== 语义违规总数 ==="
  swiftlint lint --quiet --no-cache 2>&1 | grep -cE '(warning|error):' || true
fi

echo
echo "完成。下一步见 references/swift-coding-standards.md 第 8 章（迁移与落地）。"
