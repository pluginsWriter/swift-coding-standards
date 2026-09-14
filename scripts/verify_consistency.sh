#!/usr/bin/env bash
#
# verify_consistency.sh —— 校验 skill 内部「同一事实的多个副本」是否仍然一致
#
# 为什么需要它：SKILL.md、规范正文、整改手册、命名词典、两个模板资产之间有多处
# 重复表述（验收条数、版本号、缩进与行长、规则分工、引文表）。历史上正是这些
# 手抄副本造成了漂移：drain 在手册里是「不要改」、在词典里是「必须改」；
# 正文版本表停在 v1.3 而变更记录已到 v1.5；4.6 的续行缩进残留 2 空格。
#
# 设计原则：**不写第二份期望值**。所有期望值一律从单一权威来源推导
# （条数来自手册表格行数、版本号来自变更记录末行、阈值来自模板资产），
# 再拿去比对其它副本。硬编码期望只会制造下一个漂移源。
#
# 用法：
#   bash verify_consistency.sh            # 不一致记为 FAIL；已知待决项记为 WARN
#   bash verify_consistency.sh --strict   # 已知待决项也记为 FAIL
#   bash verify_consistency.sh -h
#
# 退出码：0 = 无 FAIL；1 = 存在 FAIL；2 = 用法错误

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STRICT=0
case "${1:-}" in
  --strict) STRICT=1 ;;
  -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "未知选项: $1" >&2; exit 2 ;;
esac

FAILS=0
WARNS=0
ok()   { printf '  [OK]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; FAILS=$((FAILS + 1)); }
warn() {
  if [ "$STRICT" -eq 1 ]; then printf '  [FAIL] %s\n' "$1"; FAILS=$((FAILS + 1));
  else printf '  [WARN] %s\n' "$1"; WARNS=$((WARNS + 1)); fi
}
section() { printf '\n%s\n' "$1"; }

# 按「字符数」而非字节数计数。
# 必须显式选一个可用的 UTF-8 locale：macOS 的 awk/wc 在 C locale 下把中文按 3 字节计，
# 会让 description 这类含中文的字段被误判为超长（实测把 667 字符报成 1541）。
UTF8_LOCALE=""
for loc in C.UTF-8 en_US.UTF-8 UTF-8; do
  if [ "$(printf '中' | LC_ALL=$loc wc -m 2>/dev/null | tr -d ' ')" = "1" ]; then UTF8_LOCALE="$loc"; break; fi
done
char_len() { # stdin → 字符数
  if [ -n "$UTF8_LOCALE" ]; then LC_ALL="$UTF8_LOCALE" wc -m | tr -d ' '
  else wc -c | tr -d ' '; fi
}

MAIN="$SKILL_DIR/references/swift-coding-standards.md"
PLAYBOOK="$SKILL_DIR/references/remediation-playbook.md"
DICT="$SKILL_DIR/references/naming-antipatterns.md"
CATALOG="$SKILL_DIR/references/defect-catalog.md"
SKILL="$SKILL_DIR/SKILL.md"
FMT="$SKILL_DIR/assets/swift-format.json"
LINT="$SKILL_DIR/assets/swiftlint.yml"
REMEDIATE="$SKILL_DIR/scripts/remediate.sh"
CITATIONS_SH="$SKILL_DIR/scripts/verify_citations.sh"
OFFICIAL="$SKILL_DIR/references/official"

printf 'Swift 编码规范 skill —— 内部一致性校验\n'
printf 'skill 目录: %s\n' "$SKILL_DIR"
[ "$STRICT" -eq 1 ] && printf '模式: --strict（已知待决项也视为 FAIL）\n'

# 提取 YAML 顶层块的条目：list_of <file> <key>
list_of() {
  awk -v key="$2" '
    $0 ~ "^" key ":" { f = 1; next }
    /^[a-z_]+:/ { f = 0 }
    f && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); print }
  ' "$1"
}

# ---------------------------------------------------------------------------
section '1. 验收标准条数（权威来源：整改手册第 1 节表格）'
N_ACCEPT=$(awk '
  /^## 1\./ { s = 1; next }
  /^## 2\./ { s = 0 }
  s && /^\| *[0-9]+ *\|/ { c++ }
  END { print c + 0 }
' "$PLAYBOOK")
N_PROSE=$(grep -oE '以下 [0-9]+ 条' "$PLAYBOOK" | grep -oE '[0-9]+' | head -1)
if [ "${N_ACCEPT:-0}" -gt 0 ]; then
  ok "手册表格行数 = $N_ACCEPT 条"
else
  bad "未能从手册第 1 节解析出验收标准条数（表格格式是否变了？）"
fi
if [ -n "${N_PROSE:-}" ] && [ "$N_PROSE" != "$N_ACCEPT" ]; then
  bad "手册正文「以下 $N_PROSE 条」与表格 $N_ACCEPT 条不一致"
else
  ok "手册正文表述与表格一致"
fi
# 其余副本：SKILL.md 与 remediate.sh 里引用的条数
for f in "$SKILL" "$REMEDIATE"; do
  label=$(basename "$f")
  hits=$(grep -oE '[0-9]+ 条验收标准' "$f" | grep -oE '^[0-9]+' | sort -u | tr '\n' ' ')
  if [ -z "$hits" ]; then
    warn "$label 未引用验收条数（可接受，但引用时须与手册一致）"
  else
    for n in $hits; do
      if [ "$n" = "$N_ACCEPT" ]; then ok "$label 引用条数 = ${n}，与手册一致"
      else bad "$label 引用「$n 条验收标准」，与手册 $N_ACCEPT 条不一致"; fi
    done
  fi
done

# ---------------------------------------------------------------------------
section '2. 版本号（权威来源：规范正文变更记录末行）'
V_LOG=$(grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)? ' "$MAIN" | tail -1 | tr -d '| ')
V_HEAD=$(awk -F'|' '/^\| *版本 *\|/ { gsub(/[[:space:]]/, "", $3); print $3 }' "$MAIN" | head -1)
if [ -z "$V_LOG" ]; then
  bad "未能在正文变更记录中解析到版本号"
elif [ "$V_LOG" = "$V_HEAD" ]; then
  ok "版本表 $V_HEAD == 变更记录末行 $V_LOG"
else
  bad "版本表 $V_HEAD ≠ 变更记录末行 ${V_LOG}（改了一处忘了另一处）"
fi
for f in "$SKILL" "$PLAYBOOK"; do
  v=$(grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' "$(basename "$f" | grep -q playbook && echo "$PLAYBOOK" || echo "$SKILL")" 2>/dev/null | head -1)
  [ -n "${v:-}" ] && printf '  [note] %s 提到版本 %s（仅提示，不作为判定）\n' "$(basename "$f")" "$v"
done

# ---------------------------------------------------------------------------
section '3. 缩进与行长阈值（权威来源：assets/swift-format.json）'
LL_FMT=$(grep -oE '"lineLength"[[:space:]]*:[[:space:]]*[0-9]+' "$FMT" | grep -oE '[0-9]+')
IND_FMT=$(grep -oE '"spaces"[[:space:]]*:[[:space:]]*[0-9]+' "$FMT" | grep -oE '[0-9]+')
LL_LINT=$(awk '/^line_length:/ { f = 1; next } /^[a-z_]+:/ { f = 0 } f && /warning:/ { gsub(/[^0-9]/, "", $0); print; exit }' "$LINT")
if [ -n "$LL_FMT" ] && [ "$LL_FMT" = "$LL_LINT" ]; then
  ok "行长一致：swift-format lineLength=${LL_FMT}，swiftlint line_length.warning=$LL_LINT"
else
  bad "行长不一致：swift-format lineLength=${LL_FMT:-?}，swiftlint line_length.warning=${LL_LINT:-?}"
fi
# 模板注释里声明的列数
LL_NOTE=$(grep -oE '统一 [0-9]+ 列' "$LINT" | grep -oE '[0-9]+' | head -1)
if [ -n "$LL_NOTE" ] && [ "$LL_NOTE" != "$LL_FMT" ]; then
  bad "swiftlint.yml 注释写「统一 $LL_NOTE 列」，实际 lineLength=$LL_FMT"
else
  ok "swiftlint.yml 注释与配置一致"
fi
# 正文中的引用（若正文用 `indentation.spaces = N` / `lineLength = N` 表述）
for pair in "indentation.spaces:$IND_FMT:$MAIN:缩进" "lineLength:$LL_FMT:$MAIN:行长"; do
  key=$(printf '%s' "$pair" | cut -d: -f1)
  want=$(printf '%s' "$pair" | cut -d: -f2)
  file=$(printf '%s' "$pair" | cut -d: -f3)
  name=$(printf '%s' "$pair" | cut -d: -f4)
  for got in $(grep -oE "$key = [0-9]+" "$file" | grep -oE '[0-9]+' | sort -u); do
    if [ "$got" = "$want" ]; then ok "正文 ${name}引用 $key = ${got}，与模板一致"
    else bad "正文 ${name}引用 $key = ${got}，与模板 $want 不一致"; fi
  done
done
# 两个缩进开关必须显式开启（与 Xcode 编辑器对齐的决定，见正文 4.5）
for k in indentSwitchCaseLabels indentConditionalCompilationBlocks; do
  if grep -qE "\"$k\"[[:space:]]*:[[:space:]]*true" "$FMT"; then ok "$k = true"
  else bad "$k 未显式开启（应与 Xcode 编辑器对齐）"; fi
done

# ---------------------------------------------------------------------------
section '4. 规则分工（权威来源：assets/swiftlint.yml）'
DIS=$(list_of "$LINT" disabled_rules | sort)
OPT=$(list_of "$LINT" opt_in_rules | sort)
if [ -z "$DIS" ] || [ -z "$OPT" ]; then
  bad "未能解析 disabled_rules / opt_in_rules"
else
  CLASH=$(comm -12 <(printf '%s\n' "$DIS") <(printf '%s\n' "$OPT"))
  if [ -z "$CLASH" ]; then
    ok "禁用 $(printf '%s\n' "$DIS" | grep -c .) 条 / 启用 $(printf '%s\n' "$OPT" | grep -c .) 条，无交集"
  else
    bad "同一条规则既禁用又启用：$(printf '%s' "$CLASH" | tr '\n' ' ')"
  fi
  # 覆盖率：opt_in 规则应在正文或缺陷清单中被提到过
  MISSING=""
  for r in $OPT; do
    grep -qF "$r" "$MAIN" 2>/dev/null || grep -qF "$r" "$CATALOG" 2>/dev/null || MISSING="$MISSING $r"
  done
  if [ -z "$MISSING" ]; then
    ok "全部 opt_in 规则在正文/缺陷清单中有对应条目"
  else
    N_MISS=$(printf '%s\n' $MISSING | grep -c .)
    printf '  [note] %s 条 opt_in 规则未在正文点名（模板启用但规范未逐条描述）：%s\n' \
      "$N_MISS" "$(printf '%s' "$MISSING" | cut -c1-150)"
    printf '         建议在 references/defect-catalog.md 补「规则 → 章节」映射，避免它们静默生效\n'
  fi
fi
# swift-format 侧的语义规则开关：关闭者必须有说明（否则读者会以为无人检查）
if grep -qE '"NeverForceUnwrap"[[:space:]]*:[[:space:]]*false' "$FMT"; then
  if grep -q 'force_unwrapping' "$MAIN"; then
    ok "swift-format 关闭 NeverForceUnwrap，正文已指明由 SwiftLint force_unwrapping 承担"
  else
    warn "swift-format 关闭了 NeverForceUnwrap，但正文未说明由谁承担（易被读成「无人检查」）"
  fi
fi

# ---------------------------------------------------------------------------
section '5. 引文表（权威来源：scripts/verify_citations.sh 的 CITATIONS 数组）'
if [ -f "$CITATIONS_SH" ]; then
  ENTS=$(sed -n '/^CITATIONS=(/,/^)/p' "$CITATIONS_SH" | grep -oE '"?s[0-9]+-[a-z0-9-]+\.md' | tr -d '"' | sort)
  if [ -z "$ENTS" ]; then
    bad "未从 verify_citations.sh 解析到任何引文条目"
  else
    ok "引文条目 $(printf '%s\n' "$ENTS" | grep -c .) 条，覆盖 $(printf '%s\n' "$ENTS" | sed 's/-.*//' | sort -u | tr '\n' ' ')"
    BROKEN=0
    for f in $(printf '%s\n' "$ENTS" | sort -u); do
      [ -f "$OFFICIAL/$f" ] || { bad "引文指向的快照不存在: references/official/$f"; BROKEN=1; }
    done
    [ "$BROKEN" -eq 0 ] && ok "全部引文指向的快照文件均存在"
    SNAP=$(ls "$OFFICIAL" | grep -E '^s[0-9]+-' | sed 's/-.*//' | sort -u | tr '\n' ' ')
    printf '  [note] 快照覆盖 %s；其中无引文登记者为背景参考（S2 无快照，见 SOURCES.md）\n' "$SNAP"
  fi
else
  warn "未找到 verify_citations.sh，跳过引文表校验"
fi

# ---------------------------------------------------------------------------
section '6. frontmatter 与体量限额（Agent Skills 规范）'
NAME=$(awk '/^name:/ { sub(/^name:[[:space:]]*/, ""); print; exit }' "$SKILL")
DIRNAME=$(basename "$SKILL_DIR")
NAME_LEN=$(printf '%s' "$NAME" | char_len)
if [ "$NAME" = "$DIRNAME" ]; then ok "name「${NAME}」与目录名一致（$NAME_LEN 字符，上限 64）"
else bad "name「${NAME}」与目录名「${DIRNAME}」不一致（规范要求必须相同）"; fi
[ "$NAME_LEN" -le 64 ] || bad "name 超长：$NAME_LEN > 64"
DESC_LEN=$(awk '/^description:/ { sub(/^description:[[:space:]]*/, ""); print; exit }' "$SKILL" | char_len)
if [ "$DESC_LEN" -le 1024 ]; then ok "description $DESC_LEN 字符（上限 1024）"
else bad "description 超长：$DESC_LEN > 1024（部分 agent 会截断或拒收）"; fi
if awk '/^description:/ {n++} END {exit !(n==1)}' "$SKILL"; then
  ok "description 为单行且只出现一次（多行会破坏部分 agent 的解析）"
else
  bad "description 出现了多次或跨行"
fi
COMP_LEN=$(awk '/^compatibility:/ { sub(/^compatibility:[[:space:]]*/, ""); print; exit }' "$SKILL" | char_len)
if [ "${COMP_LEN:-0}" -eq 0 ]; then warn "未声明 compatibility 字段（建议声明环境依赖）"
elif [ "$COMP_LEN" -le 500 ]; then ok "compatibility $COMP_LEN 字符（上限 500）"
else bad "compatibility 超长：$COMP_LEN > 500"; fi
SKILL_LINES=$(grep -c . "$SKILL")
if [ "$SKILL_LINES" -le 500 ]; then ok "SKILL.md $SKILL_LINES 行（建议 ≤ 500）"
else warn "SKILL.md $SKILL_LINES 行，超过建议值 500"; fi

# ---------------------------------------------------------------------------
section '7. 已知待决漂移（默认 WARN；--strict 时视为 FAIL）'
EXC=$(list_of "$LINT" identifier_name | tr '\n' ' ')
for ch in i j; do
  if printf '%s' "$EXC" | grep -qw "$ch"; then ok "identifier_name 豁免了「${ch}」"
  else warn "identifier_name 未豁免「${ch}」，但正文 3.5 明确允许它作 ≤3 行循环计数器（会被误报）"; fi
done
TBL=$(awk '/^type_body_length:/ { f = 1; next } /^[a-z_]+:/ { f = 0 } f && /warning:/ { gsub(/[^0-9]/, "", $0); print; exit }' "$LINT")
DOC_LIMIT=$(grep -oE '单类型行数[^0-9]*[0-9]+' "$MAIN" | grep -oE '[0-9]+$' | head -1)
if [ -z "${DOC_LIMIT:-}" ]; then
  warn "未能从正文 5.8 解析出「单类型行数」上限，无法与 type_body_length.warning=$TBL 比对"
elif [ "$DOC_LIMIT" != "$TBL" ]; then
  warn "type_body_length.warning=${TBL}，而正文 5.8 承诺「单类型行数 ${DOC_LIMIT}」—— 验收要求 --strict，warning 即失败，实际卡 $TBL"
else
  ok "type_body_length=$TBL 与正文 5.8 承诺一致"
fi

# ---------------------------------------------------------------------------
section '8. 可接受词表的副本数（单一来源原则）'
COPIES=""
for f in "$SKILL" "$MAIN" "$PLAYBOOK" "$DICT"; do
  # 注意：grep -c 无匹配时退出码 1 且已输出 "0"，不能再 `|| echo 0`（会拼出两行导致整数比较报错）
  n=$(grep -c 'normalize' "$f" 2>/dev/null || true)
  [ -z "$n" ] && n=0
  [ "$n" -gt 0 ] && COPIES="$COPIES $(basename "$f"):$n"
done
CNT=$(printf '%s' "$COPIES" | wc -w | tr -d ' ')
if [ "$CNT" -le 2 ]; then ok "可接受词表副本收敛（${COPIES}）"
else warn "可接受词表出现在 $CNT 个文件：$COPIES —— 权威应为 naming-antipatterns.md，其余宜改为引用（drain 漂移即源于此）"; fi

# ---------------------------------------------------------------------------
printf '\n──────────── 汇总 ────────────\n'
printf 'FAIL: %s    WARN: %s\n' "$FAILS" "$WARNS"
if [ "$FAILS" -gt 0 ]; then
  printf '结论：存在不一致，需修正后重跑。\n'
  exit 1
fi
printf '结论：副本一致。\n'
[ "$WARNS" -gt 0 ] && printf '（%s 条 WARN 为已知待决项，见 references/../docs/skill-review/ 复盘报告）\n' "$WARNS"
exit 0
