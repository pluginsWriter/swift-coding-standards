#!/usr/bin/env bash
#
# remediate.sh —— Swift 代码规范「完整整改」管线
#
# 定位：用户显式要求「把代码改规范」时使用。本脚本负责**可自动化的那一半**：
#       采集基线 → 机械修复 → 复检 → 生成按规则分类的人工待办清单与报告。
#       命名、文档、设计类改动需人工判断，按 references/remediation-playbook.md 执行。
#
# 「完整」的定义见 references/remediation-playbook.md 第 1 节（9 条验收标准）。
# 只跑本脚本的 --fix **不等于**整改完成 —— 它只解决格式。
#
# 用法：
#   bash remediate.sh [选项] [工程目录]
#
# 选项：
#   --check              只采集基线、生成待办清单与报告（默认，不改源码）
#   --fix                执行机械修复（会修改源码，执行前必须已获用户批准）
#   --report 路径        报告输出路径（默认 工程目录/SWIFT_STANDARD_REPORT.md）
#   --dirs "目录1 目录2" 源码目录，空格分隔（默认自动探测 Sources Tests；
#                        注意：目录名本身不能含空格）
#   --max-per-rule N     每类规则最多列出多少条明细（默认 15，避免报告过长）
#   --allow-missing-config  跳过配置自动生成、直接在无配置下继续（不推荐，见下）
#   -h, --help           显示帮助
#
# 安全性：不删除任何文件；只有 --fix 会修改源码。缺配置时会**新增**两个配置文件，
#         但绝不改写已存在的 .swift-format/.swiftlint.yml。
#
# 缺配置时的行为（2026-09-11 起）：自动从 skill 资产模板生成缺失的
# .swift-format / .swiftlint.yml，并把 .swiftlint.yml 的 included 改写为本次实际
# 检查的目录。为什么必须带配置：缺少配置时工具会回退默认规则集，产生**虚假的低基线**。
# 实测（2026-09-11，swiftlint 0.63）：同一段 `print(value!)`，无 .swiftlint.yml 时报 0 条，
# 有配置时报 1 条 force_unwrapping —— opt_in 规则在无配置时完全不生效。
# 另外 .swiftlint.yml 的 included 是相对配置文件目录解析的，列出的目录不存在时
# （典型：Xcode 工程没有 Sources/）SwiftLint 会空扫并同样报 0 条 ——
# 所以自动生成时 included 一律取实际检查目录，不做「模板原样拷贝」。
# --allow-missing-config 仅用于刻意要在无配置下采基线的场景（报告会标注不可信）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_DIR=""
DIRS=""       # 显示用字符串（--dirs 原始串或数组拼接）
DIRS_A=()     # 实际执行用数组（C4：避免路径被二次切分）
MODE="check"
REPORT=""
MAX_PER_RULE=15
ALLOW_MISSING_CONFIG=0

usage() { awk 'NR>1 && /^set /{exit} NR>1{sub(/^# ?/,""); print}' "${BASH_SOURCE[0]}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check)        MODE="check"; shift ;;
    --fix)          MODE="fix";   shift ;;
    --report)       REPORT="${2:-}"; shift 2 ;;
    --dirs)         DIRS="${2:-}"; shift 2 ;;
    --max-per-rule) MAX_PER_RULE="${2:-15}"; shift 2 ;;
    --allow-missing-config) ALLOW_MISSING_CONFIG=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    -*) echo "未知选项: $1" >&2; usage; exit 2 ;;
    *)  PROJECT_DIR="$1"; shift ;;
  esac
done

[ -z "$PROJECT_DIR" ] && PROJECT_DIR="$(pwd)"
[ -d "$PROJECT_DIR" ] || { echo "错误: 目录不存在 -> $PROJECT_DIR" >&2; exit 2; }
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[ -z "$REPORT" ] && REPORT="$PROJECT_DIR/SWIFT_STANDARD_REPORT.md"

# ---------------------------------------------------------------- 工具检测
SWIFT_FORMAT_CMD=""
if swift format --version >/dev/null 2>&1; then
  SWIFT_FORMAT_CMD="swift format"
elif command -v swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT_CMD="swift-format"
fi
[ -z "$SWIFT_FORMAT_CMD" ] && {
  echo "错误: 未找到 swift-format。Swift 6.x 工具链自带 'swift format'。" >&2; exit 3; }

SWIFTLINT_OK=0
command -v swiftlint >/dev/null 2>&1 && SWIFTLINT_OK=1

# ---------------------------------------------------------------- 确定目录
# C4（2026-09-11）：目录清单由字符串拼接改为数组。此前 `$DIRS` 在命令里
# 不加引号展开，路径含空格时会被二次切分；数组展开 `"${DIRS_A[@]}"` 无此问题。
if [ -n "$DIRS" ]; then
  # shellcheck disable=SC2206  # --dirs 的契约就是空格分隔
  DIRS_A=($DIRS)
else
  for c in Sources Tests; do
    [ -d "$PROJECT_DIR/$c" ] && DIRS_A+=("$c")
  done
  [ ${#DIRS_A[@]} -eq 0 ] && DIRS_A=(".")
fi
DIRS="${DIRS_A[*]}"   # 显示用

cd "$PROJECT_DIR" || exit 2

echo "工程目录: $PROJECT_DIR"
echo "检查目录: $DIRS"
echo "格式化器: $SWIFT_FORMAT_CMD ($($SWIFT_FORMAT_CMD --version 2>/dev/null))"
[ "$SWIFTLINT_OK" -eq 0 ] && echo "警告: 未找到 swiftlint，语义检查将缺失（brew install swiftlint）" >&2

# ---------------------------------------------------------------- 配置模板校验
# 见文件头「缺配置时的行为」。此处做三件事：
#   1) 缺失的配置文件自动从 skill 资产模板生成（只新增，绝不覆盖已有文件）
#   2) 生成的 .swiftlint.yml 把 included 改写为本次实际检查目录（防 Xcode 空扫）
#   3) 已存在的 .swiftlint.yml 校验 included 列出的目录至少一个真实存在
CONFIG_MISSING=""
[ -f "$PROJECT_DIR/.swift-format" ]   || CONFIG_MISSING="$CONFIG_MISSING .swift-format"
[ -f "$PROJECT_DIR/.swiftlint.yml" ] || CONFIG_MISSING="$CONFIG_MISSING .swiftlint.yml"
CONFIG_BOOTSTRAPPED=""

if [ -n "$CONFIG_MISSING" ]; then
  if [ "$ALLOW_MISSING_CONFIG" -eq 1 ]; then
    echo "警告: 缺少${CONFIG_MISSING}，工具将回退默认规则集，基线可能虚低（--allow-missing-config 已放行，未自动生成）。" >&2
  else
    echo "缺少$CONFIG_MISSING —— 自动从 skill 资产模板生成（included 取实际检查目录）。"
    BOOTSTRAP_FAILED=""
    for f in $CONFIG_MISSING; do
      case "$f" in
        .swift-format)
          if cp "$SKILL_DIR/assets/swift-format.json" "$PROJECT_DIR/.swift-format" 2>/dev/null; then
            CONFIG_BOOTSTRAPPED="$CONFIG_BOOTSTRAPPED .swift-format"
            echo "已生成 .swift-format（4 空格 / 120 列 / indentSwitchCaseLabels）"
          else
            BOOTSTRAP_FAILED="$BOOTSTRAP_FAILED .swift-format"
          fi ;;
        .swiftlint.yml)
          # 模板默认 included 是 Sources/Tests，在 Xcode 工程（无 Sources/）下会
          # 静默空扫报 0 违规，因此生成时一律改写为本次实际检查目录。
          # 注意：BSD awk 的 -v 不接受含真实换行的值，故传空格分隔串、在 awk 内 split。
          DIRS_SP="${DIRS_A[*]}"
          if awk -v dirs="$DIRS_SP" '
            /^included:/ {
              print "included:"
              n = split(dirs, a, " ")
              for (i = 1; i <= n; i++) printf "  - %s\n", a[i]
              skip = 1; next
            }
            /^[a-z_]+:/              { skip = 0 }
            skip && /^[[:space:]]*-/ { next }
            { print }
          ' "$SKILL_DIR/assets/swiftlint.yml" > "$PROJECT_DIR/.swiftlint.yml" 2>/dev/null; then
            CONFIG_BOOTSTRAPPED="$CONFIG_BOOTSTRAPPED .swiftlint.yml"
            echo "已生成 .swiftlint.yml（included: ${DIRS_A[*]}）"
          else
            BOOTSTRAP_FAILED="$BOOTSTRAP_FAILED .swiftlint.yml"
          fi ;;
      esac
    done
    if [ -n "$BOOTSTRAP_FAILED" ]; then
      cat >&2 <<EOF
错误: $BOOTSTRAP_FAILED 自动生成失败（skill 资产模板缺失或目录不可写）

  可手动安装模板：
    bash "$SKILL_DIR/scripts/bootstrap_swift_style.sh" "$PROJECT_DIR"
  确认要在无配置下采集基线，则显式加 --allow-missing-config。
EOF
      exit 4
    fi
  fi
fi

# included 作用域校验（仅在配置文件存在时才有意义）
if [ -f "$PROJECT_DIR/.swiftlint.yml" ]; then
  INCLUDED=$(awk '
    /^included:/ { f = 1; next }
    /^[a-z_]+:/  { f = 0 }
    f && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); print }
  ' "$PROJECT_DIR/.swiftlint.yml")
  if [ -n "$INCLUDED" ]; then
    SCOPE_OK=0
    while IFS= read -r inc_dir; do
      [ -n "$inc_dir" ] && [ -d "$PROJECT_DIR/$inc_dir" ] && SCOPE_OK=1
    done <<EOF
$INCLUDED
EOF
    if [ "$SCOPE_OK" -eq 0 ]; then
      if [ "$ALLOW_MISSING_CONFIG" -eq 1 ]; then
        echo "警告: .swiftlint.yml 的 included（$(printf '%s' "$INCLUDED" | tr '\n' ' ')）在工程下都不存在，SwiftLint 会空扫并报 0 违规（已放行）。" >&2
      else
        cat >&2 <<EOF
错误: .swiftlint.yml 的 included 作用域为空

  当前 included: $(printf '%s' "$INCLUDED" | tr '\n' ' ')
  这些目录在 $PROJECT_DIR 下都不存在，而 included 是相对「配置文件所在目录」解析的，
  于是 SwiftLint 一条都不扫 —— 报告会显示「0 违规」，但实际什么都没检查。

  Xcode 工程（.xcodeproj / .xcworkspace）通常没有 Sources/，必然踩中这一条。
  处理：把 included 改成真实源码目录（如由 --dirs 指定的那些），或删掉 included
        只保留 excluded（SwiftLint 默认递归当前目录）。

  确认要继续，则显式加 --allow-missing-config。
EOF
        exit 4
      fi
    fi
  fi
fi
echo

# ---------------------------------------------------------------- 采集工具
# 两个必须注意的实测坑：
#
#  坑一：`swift format lint` 把违规**全部写到 stderr**（stdout 为空）。
#        必须用 2>&1 捕获；用 2>/dev/null 会得出「零违规」的错误结论。
#
#  坑二：`swift format lint` 会**重复输出同一条违规**（实测约 3.5 倍）。
#        例如某工程 Sources 原始输出 1797 行，去重后仅 513 条，
#        而该目录真实分号数为 519 —— 可见去重后的数才接近真相。
#        因此所有计数一律先按整行去重，否则报告数字会严重虚高。
#
# 去重口径：格式违规按 `文件:行:列:规则` 去重；语义违规按 `文件:行:列:规则` 去重。
# 每个阶段只跑一次全量 lint，原始输出缓存为字符串，计数与分布全部由缓存派生。
# （缓存前 --check 模式要跑 6 遍 swift-format + 7 遍 swiftlint；缓存后各 1 遍，
#   --fix 模式因修复后必须复采，各 2 遍。大工程下一次全量 lint 以秒计，重复即浪费。）
format_raw() {
  $SWIFT_FORMAT_CMD lint --recursive "${DIRS_A[@]}" 2>&1 \
    | grep -E '\[[A-Za-z]+\]' | sort -u
}

# 以下三个函数都从 stdin 读取「已缓存的原始输出」，不再触发新的 lint：
raw_count() { grep -c . || true; }

fmt_dist() { grep -oE '\[[A-Za-z]+\]' | sort | uniq -c | sort -rn; }

# 输出 `file<TAB>line<TAB>col<TAB>rule`，按位置去重。
# 用 awk 而非 sed：BSD sed 对本机需要的正则（分组 + 交替）解析失败，
# 且 swiftlint 行格式固定为 `FILE:LINE:COL: LEVEL: MSG (RULE)`。
lint_rows() {
  [ "$SWIFTLINT_OK" -eq 1 ] || return 0
  swiftlint lint --quiet --no-cache 2>/dev/null | awk '
    {
      if (!match($0, /\([a-z_]+\)[ \t]*$/)) next
      rule = substr($0, RSTART + 1, RLENGTH - 2)
      split($0, parts, ": ")
      loc = parts[1]
      if (match(loc, /:[0-9]+:[0-9]+$/)) {
        tail = substr(loc, RSTART + 1)
        split(tail, t, ":")
        printf "%s\t%s\t%s\t%s\n", substr(loc, 1, RSTART - 1), t[1], t[2], rule
      }
    }' | sort -u
}

lint_dist() { awk -F'\t' '$4!=""{print $4}' | sort | uniq -c | sort -rn; }

# 需人工判断的规则（格式类由 swift-format 全自动处理，不在其中）
MANUAL_RULES="identifier_name force_unwrapping force_cast force_try implicitly_unwrapped_optional missing_docs large_tuple discouraged_optional_boolean implicit_optional_initialization xctfail_message xct_specific_matcher modifier_order unneeded_synthesized_initializer function_body_length type_body_length cyclomatic_complexity line_length"

rule_action() {
  case "$1" in
    identifier_name)       echo "命名：只改「读不懂」的三类（单字母 / 自造缩写 / 生僻词 / 超长名）；normalize、perform、u16 等常用词不改（规范 3.1）" ;;
    force_unwrapping)      echo "强制解包：改 guard let / if let，或 preconditionFailure + 不变式注释" ;;
    force_cast)            echo "as!：改 as? + guard let" ;;
    force_try)             echo "try!：改 do/catch 或向上 throws" ;;
    implicitly_unwrapped_optional) echo "隐式解包可选：除 @IBOutlet 外改普通可选或非可选" ;;
    missing_docs)          echo "补 /// 文档：摘要 → 参数 → 返回值 → Throws（见 references/comment-standards.md）" ;;
    large_tuple)           echo "元组过大（>2 成员）：提取为具名 struct" ;;
    discouraged_optional_boolean)  echo "可选布尔：改独立状态枚举" ;;
    implicit_optional_initialization) echo "可选初始化：删掉冗余的 = nil" ;;
    xctfail_message)       echo "断言缺失败说明：补第三个参数" ;;
    xct_specific_matcher)  echo "断言过弱：改用专用断言（XCTAssertTrue(a == b) → XCTAssertEqual(a, b)）" ;;
    modifier_order)        echo "修饰符顺序：nonisolated 在访问修饰符之前（以 swiftlint 配置为准）" ;;
    unneeded_synthesized_initializer) echo "冗余 init：删除可自动合成的初始化器" ;;
    function_body_length)  echo "函数过长：按职责拆分" ;;
    type_body_length)      echo "类型过大：按职责拆分文件/扩展" ;;
    cyclomatic_complexity) echo "圈复杂度过高：用查表/状态枚举替换分支链，再抽取具名函数" ;;
    line_length)           echo "超长行：优先由 swift-format 断行；仍超限则提取中间变量" ;;
    unused_import)         echo "无用 import：删除" ;;
    *)                     echo "见 references/swift-coding-standards.md 对应章节" ;;
  esac
}

# ---------------------------------------------------------------- 基线
FMT_RAW="$(format_raw)"
LINT_RAW="$(lint_rows)"
FMT_BEFORE=$(printf '%s\n' "$FMT_RAW" | raw_count)
LINT_BEFORE=$(printf '%s\n' "$LINT_RAW" | raw_count)
echo "=== 整改前基线 ==="
echo "格式违规: $FMT_BEFORE    语义违规: $LINT_BEFORE"
echo

# ---------------------------------------------------------------- 机械修复
FIXED=0
if [ "$MODE" = "fix" ]; then
  cat <<'EOF'
⚠️  --fix 将执行 swift format --in-place 与 swiftlint --fix，会修改源码。
    请确认已获用户批准，且工作区已提交或已备份（便于回滚与 review）。

EOF
  SNAP_BEFORE=$(find "${DIRS_A[@]}" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
  $SWIFT_FORMAT_CMD --in-place --recursive "${DIRS_A[@]}"
  [ "$SWIFTLINT_OK" -eq 1 ] && swiftlint lint --fix --quiet --no-cache >/dev/null 2>&1
  SNAP_AFTER=$(find "${DIRS_A[@]}" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
  FIXED=1
  echo "机械修复完成（源文件数 $SNAP_BEFORE -> ${SNAP_AFTER}）。"
  echo
fi

# ---------------------------------------------------------------- 复检
# 只有 --fix 实际改过源码才重新采集；--check 模式直接复用基线缓存
if [ "$FIXED" -eq 1 ]; then
  FMT_RAW="$(format_raw)"
  LINT_RAW="$(lint_rows)"
fi
FMT_AFTER=$(printf '%s\n' "$FMT_RAW" | raw_count)
LINT_AFTER=$(printf '%s\n' "$LINT_RAW" | raw_count)

echo "=== 复检 ==="
echo "格式违规: $FMT_BEFORE -> $FMT_AFTER"
echo "语义违规: $LINT_BEFORE -> $LINT_AFTER"
echo

# ---------------------------------------------------------------- 生成报告
# 计数与分布全部由缓存派生，不再触发任何新的 lint
LINT_ROWS="$LINT_RAW"
FMT_DIST="$(printf '%s\n' "$FMT_RAW" | fmt_dist)"
LINT_DIST="$(printf '%s\n' "$LINT_RAW" | lint_dist)"

{
  echo "# Swift 规范整改报告"
  echo
  echo "生成时间：$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "工程目录：\`$PROJECT_DIR\`"
  echo "检查目录：\`$DIRS\`"
  echo "执行模式：$( [ "$MODE" = "fix" ] && echo '已执行机械修复（--fix）' || echo '只读检查（--check）' )"
  echo "配置模板：$( if [ -n "$CONFIG_BOOTSTRAPPED" ]; then echo "初始缺失，已自动生成 ${CONFIG_BOOTSTRAPPED}（included 取实际检查目录）"; elif [ -n "$CONFIG_MISSING" ]; then echo '**缺失**（--allow-missing-config 放行，下述基线与违规数不可信）'; else echo '已就位（`.swift-format` + `.swiftlint.yml`）'; fi )"
  echo
  echo "> 完整验收标准见 \`references/remediation-playbook.md\` 第 1 节（9 条）。"
  echo "> **本报告只覆盖可自动化部分。命名、文档、设计类改动需按手册人工完成后再补记。**"
  echo
  echo "## 1. 前后对比"
  echo
  echo "| 指标 | 整改前 | 整改后 |"
  echo "| --- | --- | --- |"
  echo "| 格式违规总数 | $FMT_BEFORE | $FMT_AFTER |"
  echo "| 语义违规总数 | $LINT_BEFORE | $LINT_AFTER |"
  echo
  echo "计数口径：均已按 \`文件:行:列:规则\` 去重，统计的是**唯一违规位置数**。"
  echo "注意 \`swift format lint\` 会重复输出同一条违规（实测约 3.5 倍），未去重的数字会严重虚高，"
  echo "因此不要直接拿 \`swift format lint | wc -l\` 的结果与此表对比。"
  echo
  echo "## 2. 格式违规分布（swift-format）"
  echo
  if [ -n "$FMT_DIST" ]; then
    echo '```'
    echo "$FMT_DIST"
    echo '```'
  else
    echo "无。"
  fi
  echo
  echo "## 3. 语义违规分布（SwiftLint）"
  echo
  if [ "$SWIFTLINT_OK" -eq 0 ]; then
    echo "未检测到 swiftlint，本节缺失。"
  elif [ -n "$LINT_DIST" ]; then
    echo '```'
    echo "$LINT_DIST"
    echo '```'
  else
    echo "无。"
  fi
  echo
  echo "## 4. 待人工处理清单"
  echo
  echo "以下按规则分组，每类最多列 $MAX_PER_RULE 条明细。逐条按整改动作处理后删除对应条目。"
  echo
  if [ -z "$LINT_ROWS" ]; then
    echo "无待处理项。"
  else
    for rule in $MANUAL_RULES; do
      cnt=$(printf '%s\n' "$LINT_ROWS" | awk -F'\t' -v r="$rule" '$4==r' | grep -c . || true)
      [ "${cnt:-0}" -eq 0 ] && continue
      echo "### \`$rule\`（$cnt 处）"
      echo
      echo "整改动作：$(rule_action "$rule")"
      echo
      echo '```'
      printf '%s\n' "$LINT_ROWS" | awk -F'\t' -v r="$rule" '$4==r {print $1":"$2}' \
        | sed "s|$PROJECT_DIR/||" | head -n "$MAX_PER_RULE"
      [ "$cnt" -gt "$MAX_PER_RULE" ] && echo "… 其余 $((cnt - MAX_PER_RULE)) 处（用 swiftlint lint 查看全部）"
      echo '```'
      echo
    done
    # 未列入 MANUAL_RULES 的其余规则
    other=$(printf '%s\n' "$LINT_ROWS" | awk -F'\t' -v list="$MANUAL_RULES" '
      BEGIN{n=split(list,a," "); for(i=1;i<=n;i++) seen[a[i]]=1}
      $4!="" && !seen[$4] {print $4}' | sort | uniq -c | sort -rn)
    if [ -n "$other" ]; then
      echo "### 其他规则"
      echo
      echo '```'
      echo "$other"
      echo '```'
      echo
      echo "整改动作：见 \`references/swift-coding-standards.md\` 对应章节。"
      echo
    fi
  fi
  echo "## 5. 完成前必须执行的终检"
  echo
  echo '```bash'
  echo "swift format lint --recursive --strict $DIRS   # 必须无输出"
  echo "swiftlint lint --strict --quiet                 # 必须无输出（注意 --strict）"
  echo '```'
  echo
  echo "## 6. 提交拆分要求"
  echo
  echo "- 格式改动：每个 Target 一个提交，\`style: apply swift-format to TARGET_NAME\`"
  echo "- 语义/命名改动：与格式提交**分开**"
  echo "- public API 重命名：先写 ADR，单独成批，完整回归受影响测试"
  echo
  echo "## 7. 仍需人工补记"
  echo
  echo "- [ ] 已自动修复项（按规则列数量）"
  echo "- [ ] 已人工修复项（逐条列 \`文件:行\` 与改法）"
  echo "- [ ] 剩余项与理由（不是「太麻烦」）"
  echo "- [ ] 提交拆分清单"
  echo "- [ ] 未验证项（测试因环境原因未跑时明确写出）"
} > "$REPORT"

echo "报告已生成: $REPORT"
echo

# ---------------------------------------------------------------- 终检判定
OK=1
[ "$FMT_AFTER" -gt 0 ] && OK=0
[ "$SWIFTLINT_OK" -eq 1 ] && [ "$LINT_AFTER" -gt 0 ] && OK=0

if [ "$OK" -eq 1 ]; then
  echo "✅ 自动可检查部分全部通过（格式与语义零违规）。"
  echo "   仍需按 references/remediation-playbook.md 确认命名/文档/设计项。"
  exit 0
fi

echo "⚠️  尚有违规未清零，整改未完成："
[ "$FMT_AFTER" -gt 0 ] && echo "   - 格式违规 $FMT_AFTER 处（可再跑 --fix）"
[ "$SWIFTLINT_OK" -eq 1 ] && [ "$LINT_AFTER" -gt 0 ] && echo "   - 语义违规 $LINT_AFTER 处（见报告第 4 节待办清单）"
echo "   完整清单与整改动作见: $REPORT"
exit 1
