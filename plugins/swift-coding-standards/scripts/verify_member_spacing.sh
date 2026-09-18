#!/usr/bin/env bash
#
# verify_member_spacing.sh —— 检查「成员声明之间是否缺一个空行」
#
# 背景：正文 4.7 早就把「类型声明之间、成员方法之间空 1 行」定为 MUST，但这条规则
#       此前**没有任何工具能查** —— swift-format 6.3.3 的 38 条规则里没有「成员间空行」
#       （配置项只有 maximumBlankLines，管的是上限不是下限；实测把两个相邻 func 喂给
#       swift format，输出与输入一致，不补空行）；SwiftLint 0.63 同样没有对应规则。
#       结果是这条规则只写在纸上，实际工程里大量违反却无人发现。
#       本脚本把它变成可机器检出的，判据见下。
#
# 判据（与 S5 §Vertical Whitespace 对齐）：
#   若某声明行 D 的上一个**代码行** C 恰好是独立的一行 `}`，且 C 与 D 缩进相同，
#   且 C 与 D 之间没有任何空行，且 D 是「成员级声明」，则判定为缺空行。
#
#   「成员级声明」= func / init / deinit / subscript / 嵌套类型（struct class enum
#   protocol extension actor typealias）/ **带花括号体的 var、let**（计算属性、属性观察器、
#   闭包初始化的存储属性）。
#
#   按 S5 的两个例外**主动排除**，不算违规：
#     - 单行存储属性之间（`let a = 1` 这类没有花括号体的属性：可空可不空，用于逻辑分组）
#     - 单行 enum case 之间（同上）
#   因此本脚本不检查属性分组与 case 分组，只看「有体的成员」。
#
# 已知边界（诚实的漏检，不是误报）：
#   - 成员结尾不是 `}` 的情形查不到（如多行数组字面量 `]` 结尾、`#endif` 结尾）；
#   - 缩进用 Tab 时与空格比较不相等，可能漏检（正文 4.5 本就禁止 Tab）；
#   - `let x = foo { $0 }` 这类单行尾随闭包属性会按「有体成员」处理（S5 例外只覆盖
#     纯单行存储属性声明）。
#
# 用法：
#   bash verify_member_spacing.sh <目录>...            # 只报告，不改文件（默认即只读）
#   bash verify_member_spacing.sh <目录>... --check    # 同上，显式声明只读意图（适合写进 CI）
#   bash verify_member_spacing.sh <目录>... --fix      # 插入缺失的空行（会改源码）
#   bash verify_member_spacing.sh <目录>... --quiet    # 只输出汇总
#   bash verify_member_spacing.sh -h
#
# 退出码：0 = 无违规（或 --fix 已执行完毕）；1 = 存在违规；2 = 用法错误
#
# 注意：--fix 只插入一个空行，不触碰任何语句，属正文 4.0 定义的纯格式变更；
#       仍应与逻辑改动分开提交（正文「迁移纪律」）。
#       树上有在制品时如何把纯格式增量拆出来（含 git apply 静默跳过的坑），
#       见 references/remediation-playbook.md「第 ③ 步的补救」。

set -uo pipefail

usage() { sed -n '2,/^[[:space:]]*$/p' "$0" | sed 's/^# \{0,1\}//'; }

FIX=0
QUIET=0
DIRS=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --fix) FIX=1 ;;
    --check) FIX=0 ;;   # 显式只读（只读本就是默认），便于在 CI 里声明意图
    --quiet) QUIET=1 ;;
    -*) echo "未知选项：$arg" >&2; usage >&2; exit 2 ;;
    *) DIRS="$DIRS $arg" ;;
  esac
done

if [ -z "${DIRS# }" ]; then
  echo "用法错误：至少需要一个目录参数。" >&2
  usage >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# awk 主体：逐行扫描，识别「} 后紧跟成员声明且无空行」
# 用 awk 而非 sed：正文 8.2 记录过 BSD sed 对分组+交替正则解析失败，awk 可靠。
# ---------------------------------------------------------------------------
AWK_PROG='
BEGIN {
  code_ind = -1
  code_was_rbrace = 0
  buf_n = 0
  buf_start = 0
  had_blank = 0
}
function indent_of(s,   m) { m = match(s, /^[[:space:]]*/); return RLENGTH }
function rtrim(s) { sub(/[[:space:]]+$/, "", s); return s }
function ltrim(s) { sub(/^[[:space:]]+/, "", s); return s }

# 反复剥离属性与修饰符，判断剩下的开头是不是成员级声明
function is_member(s,   t) {
  t = s
  while (1) {
    if (t ~ /^@[A-Za-z_][A-Za-z0-9_]*\([^)]*\)[[:space:]]+/) {
      sub(/^@[A-Za-z_][A-Za-z0-9_]*\([^)]*\)[[:space:]]+/, "", t); continue
    }
    if (t ~ /^@[A-Za-z_][A-Za-z0-9_]*[[:space:]]+/) {
      sub(/^@[A-Za-z_][A-Za-z0-9_]*[[:space:]]+/, "", t); continue
    }
    if (t ~ /^(public|private|internal|fileprivate|open|static|final|override|mutating|nonmutating|nonisolated|convenience|required|lazy|weak|unowned|indirect|dynamic|prefix|postfix|infix)[[:space:]]+/) {
      sub(/^(public|private|internal|fileprivate|open|static|final|override|mutating|nonmutating|nonisolated|convenience|required|lazy|weak|unowned|indirect|dynamic|prefix|postfix|infix)[[:space:]]+/, "", t)
      continue
    }
    break
  }
  if (t ~ /^(func|init|deinit|subscript|struct|class|enum|protocol|extension|actor|typealias)([^A-Za-z0-9_]|$)/) return 1
  if (t ~ /^(var|let)[[:space:]]/ && index(s, "{") > 0) return 1
  return 0
}

# 处理缓冲的注释行：emit=1 时输出内容，insert_blank=1 时先在块首插入空行。
# buf_n 必须**无条件**清零 —— 只用于判定的模式（--check）若不清零，buf_start 会一直
# 停在文件里的第一条注释上，导致该文件所有命中都报同一个行号（实测踩过这个坑）。
function flush(insert_blank, emit,   i) {
  if (emit) {
    if (insert_blank) print ""
    for (i = 1; i <= buf_n; i++) print buf[i]
  }
  buf_n = 0
}

{
  # --check 走「所有文件一次交给 awk」的快路径，必须按文件重置状态：
  # 否则上一个文件末尾的 `}` 会被当成下一个文件首个声明的前一行，产生跨文件误报。
  if (FNR == 1) {
    code_ind = -1; code_was_rbrace = 0; buf_n = 0; buf_start = 0; had_blank = 0
  }
  fn = (fname == "") ? FILENAME : fname

  s = rtrim($0)
  t = ltrim(s)

  if (t == "") {                      # 空行：已有分隔，先吐缓冲再吐空行本身
    flush(0, fix)
    if (fix) print $0                 # 空行必须显式打印，否则会被静默删除
    had_blank = 1
    next
  }
  if (t ~ /^\/\//) {                  # 注释行：连同它一起缓冲（空行要插在注释之前）
    if (buf_n == 0) buf_start = FNR
    buf[++buf_n] = $0
    next
  }

  hit = 0
  if (code_was_rbrace && !had_blank && is_member(t) && indent_of(s) == code_ind) { hit = 1 }
  if (hit) {
    hits++
    # 报告声明自身的行号（人最容易找到的位置）；若中间夹着文档注释，
    # 空行要插在注释块之前（注释属于该声明），额外标出插入点，避免报的行号
    # 与 --fix 实际动的位置对不上。
    if (buf_n > 0) {
      printf "%s:%d: %s  [空行插入点：第 %d 行前]\n", fn, FNR, t, buf_start > hitsfile
    } else {
      printf "%s:%d: %s\n", fn, FNR, t > hitsfile
    }
  }
  flush(hit, fix)
  if (fix) print $0

  # 更新「上一个代码行」的状态（空行与注释行不更新，才能跨过注释找到真正的上一行）
  # 注意用左对齐后的 t 比较，不能用仍带缩进的 s —— 顶层之外的行永远不等于 "}"，
  # 会让判定静默失效（实测踩过：只剩文件顶层类型被检出）。
  code_ind = indent_of(s)
  code_was_rbrace = (t == "}") ? 1 : 0
  had_blank = 0
}

END {
  # 文件以注释块结尾时缓冲尚未吐出，不处理会丢内容
  flush(0, fix)
}
'

ALL_HITS="$(mktemp)"
trap 'rm -f "$ALL_HITS"' EXIT

FILES_A=()
for d in ${DIRS# }; do
  if [ ! -d "$d" ]; then
    echo "跳过不存在的目录：$d" >&2
    continue
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    FILES_A[${#FILES_A[@]}]="$f"
  done < <(find "$d" -name '*.swift' -type f \
             -not -path '*/DerivedData/*' -not -path '*/.build/*' \
             -not -path '*/Pods/*' -not -path '*/.git/*' | sort)
done
N_FILES=${#FILES_A[@]}

if [ "$N_FILES" -eq 0 ]; then
  echo "未找到任何 .swift 文件，检查目录参数：${DIRS# }" >&2
  exit 2
fi

[ "$QUIET" -eq 0 ] && { echo "检查成员间空行（判据见脚本头部）"; echo "扫描 $N_FILES 个 .swift 文件"; echo; }

CHANGED=0
if [ "$FIX" -eq 0 ]; then
  # 只读模式：所有文件一次性交给 awk 单进程。逐文件 fork 一次 awk 在 200 文件规模
  # 要 45 秒，单进程走完同样内容只需个位数秒（实测）。行号用 FNR，仍是文件内行号。
  awk -v fname="" -v hitsfile="$ALL_HITS" -v fix=0 "$AWK_PROG" "${FILES_A[@]}" > /dev/null
else
  # 修复模式：必须逐文件处理，才能把改写后的内容分别写回各自的源文件。
  OUT="$(mktemp)"
  for f in "${FILES_A[@]}"; do
    HF="$(mktemp)"
    awk -v fname="$f" -v hitsfile="$HF" -v fix=1 "$AWK_PROG" "$f" > "$OUT"
    if ! cmp -s "$f" "$OUT"; then
      cat "$OUT" > "$f"        # 原地覆盖，保留原文件 inode 与权限
      CHANGED=$((CHANGED + 1))
    fi
    cat "$HF" >> "$ALL_HITS"
    rm -f "$HF"
  done
  rm -f "$OUT"
fi

N_HITS=$(grep -c . "$ALL_HITS" 2>/dev/null || true)
N_HITS=${N_HITS:-0}
N_HIT_FILES=$(cut -d: -f1 "$ALL_HITS" | sort -u | grep -c . 2>/dev/null || true)
N_HIT_FILES=${N_HIT_FILES:-0}

if [ "$QUIET" -eq 0 ] && [ "$N_HITS" -gt 0 ]; then
  sort -t: -k1,1 -k2,2n "$ALL_HITS"
  echo
fi

echo "──────── 汇总 ────────"
echo "成员声明前缺空行：$N_HITS 处，涉及 $N_HIT_FILES 个文件（共扫描 $N_FILES 个）"
if [ "$FIX" -eq 1 ]; then
  echo "已修正 $CHANGED 个文件（仅插入空行，未触碰任何语句）"
  echo "复查：bash \"$0\" ${DIRS# } --quiet"
  exit 0
fi

if [ "$N_HITS" -gt 0 ]; then
  cat <<'EOF'

整改：这是可机械修复的纯格式项，但仍属「格式提交」，不得与逻辑改动混在一起。
  bash <本脚本> <目录>... --fix
EOF
  exit 1
fi
echo "结论：未发现缺空行。"
exit 0
