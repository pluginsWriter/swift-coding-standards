#!/usr/bin/env bash
#
# verify_citations.sh —— 校验规范正文中的「原文引用」是否与离线快照一致
#
# 背景：references/swift-coding-standards.md 中加引号或斜体标注为原文的句子，
#       必须是来源文本的逐字引用。改写句伪装成原文是最容易发生、也最难被发现的
#       规范缺陷（v1.0 就出现过一次，v1.1 修正）。
#
# 本脚本做**双向**校验（单向检查会漏掉「正文改了但引文表没改」这类漂移）：
#   方向一：引文表中每一句，必须能在对应快照里逐字检索到  —— 防止误引
#   方向二：引文表中每一句，必须真的出现在规范正文里        —— 防止引文表虚挂
#
# 另有**反向启发扫描**（第三道，2026-09-11 新增）：正文中以斜体标注的英文句
# 按引文纪律必须是快照原文。引文表只能覆盖「登记过的」引文，查不出
# 「正文新加了斜体引文却没登记」—— 这一方向的漂移此前完全靠人自觉。
# 扫描方式：去掉 **加粗** 后提取正文里的 *英文斜体片段*（≥12 字符且含空格），
# 逐句到全部快照中检索，找不到即记 [REV] 失败。局限：只覆盖单行斜体，
# 反引号标注的引文与跨行引文仍需登记引文表才能被查到。
#
# 用法：
#   bash verify_citations.sh            # 校验，输出逐条结果
#   bash verify_citations.sh --quiet    # 只输出失败项与总结
#
# 退出码：0 全部通过；1 有任一方向失败，或快照缺失

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$SKILL_DIR/references/swift-coding-standards.md"
OFFICIAL="$SKILL_DIR/references/official"

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

if [ ! -f "$SPEC" ]; then
  echo "找不到规范正文：$SPEC" >&2
  exit 1
fi

# 引文表：快照文件|原文片段
# 字符串必须是快照中真实存在的连续文本，且必须原样出现在规范正文里。
# 新增或修改引文时在此登记；只加原文、不加引文表，等于没有纪律。
CITATIONS=(
  # —— S1 Swift API Design Guidelines ——
  "s1-api-design-guidelines.md|Clarity is more important than brevity"
  "s1-api-design-guidelines.md|Clarity at the point of use"
  "s1-api-design-guidelines.md|Avoid obscure terms"
  "s1-api-design-guidelines.md|Don't say “epidermis” if “skin” will serve your purpose"
  "s1-api-design-guidelines.md|Include all the words needed to avoid ambiguity"
  "s1-api-design-guidelines.md|Compensate for weak type information"
  "s1-api-design-guidelines.md|Those with side-effects should read as imperative verb phrases"
  "s1-api-design-guidelines.md|Uses of Boolean methods and properties should read as assertions"
  "s1-api-design-guidelines.md|Begin names of factory methods with"
  "s1-api-design-guidelines.md|Protocols that describe"
  # —— S5 Google Swift Style Guide（行业权威）——
  # 只登记这 1 句：§Vertical Whitespace 的除外条款在快照里跨行排布，逐字引用会落成
  # 多行片段而 grep -F 查不到，故正文 4.7 对除外条款采用转述（不标引号），只引主句。
  "s5-google-swift-style-guide.md|A single blank line appears in the following locations:"
  # —— S6 LinkedIn Swift Style Guide（行业参考）——
  "s6-linkedin-swift-style-guide.md|If you’re returning 3 or more items in a tuple, consider using a \`struct\` or \`class\` instead."
  "s6-linkedin-swift-style-guide.md|make sure that this value is appropriately labeled as opposed to just types"
  "s6-linkedin-swift-style-guide.md|Don't use \`unowned\`."
  "s6-linkedin-swift-style-guide.md|Use \`XCTUnwrap\` instead of forced unwrapping in tests"
  "s6-linkedin-swift-style-guide.md|Ensure that there is a newline at the end of every file."
  "s6-linkedin-swift-style-guide.md|Ensure that there is no trailing whitespace anywhere"
  "s6-linkedin-swift-style-guide.md|If you have a default case that shouldn't be reached, preferably throw an error"
)

pass=0
fail=0
missing_snapshot=0
not_in_spec=0

[ "$QUIET" -eq 0 ] && { echo "校验引文（正文：references/swift-coding-standards.md）"; echo; }

for entry in "${CITATIONS[@]}"; do
  file="${entry%%|*}"
  needle="${entry#*|}"
  path="$OFFICIAL/$file"

  if [ ! -f "$path" ]; then
    printf "  [MISS] 快照缺失 %s —— 先运行 fetch_official_sources.sh\n" "$file"
    fail=$((fail + 1))
    missing_snapshot=1
    continue
  fi

  # 方向一：快照里有没有这句原文
  if ! grep -qF "$needle" "$path"; then
    printf "  [BAD ] %-34s 快照中找不到：%s\n" "$file" "$needle"
    fail=$((fail + 1))
    continue
  fi

  # 方向二：正文有没有真的引用它
  if ! grep -qF "$needle" "$SPEC"; then
    printf "  [ORPH] %-34s 正文未引用（引文表虚挂）：%s\n" "$file" "$needle"
    fail=$((fail + 1))
    not_in_spec=1
    continue
  fi

  pass=$((pass + 1))
  [ "$QUIET" -eq 0 ] && printf "  [ OK ] %-34s %s\n" "$file" "$needle"
done

# ---------------------------------------------------------------------------
# 反向启发扫描：正文斜体英文句必须是某一份快照的原文（见文件头说明）
# ---------------------------------------------------------------------------
reverse_pass=0
reverse_fail=0
# 先剔除 **加粗**，避免加粗内容被误提取为斜体（**text** 会残留 *text* 的匹配）
spec_stripped="$(sed 's/\*\*[^*]*\*\*/ /g' "$SPEC")"
while IFS= read -r frag; do
  [ -n "$frag" ] || continue
  hit=0
  for snap in "$OFFICIAL"/*.md; do
    [ -f "$snap" ] || continue
    if grep -qF -- "$frag" "$snap"; then hit=1; break; fi
  done
  if [ "$hit" -eq 1 ]; then
    reverse_pass=$((reverse_pass + 1))
  else
    printf "  [REV ] 正文斜体英文句未在任何快照中找到：%s\n" "$frag"
    reverse_fail=$((reverse_fail + 1))
    fail=$((fail + 1))
  fi
done < <(printf '%s\n' "$spec_stripped" \
  | grep -oE '\*[A-Za-z“][^*]{11,}\*' | tr -d '*')

echo
printf "引文校验：%d 通过，%d 失败\n" "$pass" "$fail"
printf "反向扫描：%d 句斜体英文有快照出处，%d 句无出处\n" "$reverse_pass" "$reverse_fail"

if [ "$fail" -gt 0 ]; then
  cat <<'EOF'

未通过的可能原因：
  BAD  —— 引文与快照不符：快照陈旧则先刷新；否则改为逐字引用，或去掉引号明确标注为转述。
  ORPH —— 引文表里登记了正文其实没引用的句子：删除该条，或把引文补进正文。
  MISS —— 快照文件缺失：运行 fetch_official_sources.sh 补齐。
  REV  —— 正文里的斜体英文句在任何快照中都找不到：要么改为逐字引用，要么去掉斜体
          标注（转述不加引号/斜体）；确属原文则先刷新快照再复查。
EOF
  [ "$not_in_spec" -eq 1 ] && echo "（注意：ORPH 说明引文表与正文已经漂移，两边必须同步。）"
  exit 1
fi

exit 0
