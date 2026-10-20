#!/usr/bin/env bash
#
# verify_file_header.sh —— 检查「Swift 文件头是否符合正文 4.10 的八行三段结构」
#
# 背景：正文 4.10 把标准文件头定为 MUST（定位块 / 创作块 / 作用块），但 swift-format
#       与 SwiftLint 都没有文件头规则，这条此前只写在纸上。本脚本把它变成可机器
#       检出的，判据见下。
#
# 标准头（8 行，含首尾分隔；与 Xcode IDETemplateMacros 模板一致）：
#   //
#   //  <文件名>.swift          ← 必须与磁盘文件名一致
#   //  <项目名>
#   //
#   //  Created by <创建者> on <yyyy/M/d>.
#   //  Copyright © <yyyy> <主体>. All rights reserved.
#   //
#   //  文件作用：<一句话，说明这个文件干什么>
#
# 判据（查结构不查值，这是「默认生成」与「手动修改」能并存的关键）：
#   - **创建者字段不校验与当前设备一致**：只查「Created by … on …」结构存在、
#     日期为 yyyy/M/d 格式（允许不补零）。谁创建的、哪天创建的，都是创建时的事实，
#     事后手动修改不算违规。
#   - **日期只查格式不查数值**：文件 mtime 会变，拿 mtime 对日期必然误报。
#   - **版权主体默认不校验**：通用规范只查「Copyright © yyyy … All rights reserved.」
#     结构；传 `--copyright "UGREEN. All rights reserved."` 后才严校主体。
#   - **「文件作用」行查存在、非空、非 TODO 占位**；写得准不准靠 code review
#     （正文 4.10 的判据，机器不越界）。
#
# --fix 的边界（只补结构，绝不编内容）：
#   - 只处理**整块缺失**的文件（首行不是 // 注释）：生成标准头后接原文。
#     文件名、日期、创建者自动填（创建者取 macOS 账户全名，空则回退用户名；
#     项目名取 git 仓库根名，非 git 目录留 TODO 占位）。
#   - 「文件作用」永远填 `TODO（需人工补写）` —— 生成假描述比缺描述更糟。
#   - 已有注释头但结构不完整的文件**跳过不修**（覆盖别人的头风险太高），只报告。
#   - 修完后 --check 仍会报 TODO 占位，直到人工补写 —— 这是有意的。
#
# 已知边界（诚实的漏检，不是误报）：
#   - 只看前 12 行的行前缀与行号，不解析 Swift 语法；头部行若带行尾注释会判不匹配；
#   - 多行「文件作用」（第 9 行起以 // 续行）不校验续行内容；
#   - 以 /* */ 块注释开头或带 SPDX 头的第三方文件请放行到排除目录，不要逐个豁免。
#
# 用法：
#   bash verify_file_header.sh Sources Tests         # 只报告，不改文件（默认即只读）
#   bash verify_file_header.sh Sources Tests --check # 同上，显式声明只读意图（适合写进 CI）
#   bash verify_file_header.sh Sources Tests --fix   # 给缺头的文件补标准头（会改源码）
#   bash verify_file_header.sh Sources Tests --quiet # 只输出汇总
#   bash verify_file_header.sh Sources --copyright "UGREEN. All rights reserved."
#   bash verify_file_header.sh -h, --help
#
#   目录用空格分隔，可给多个；**至少需要一个，脚本不自动探测**。
#   示例里的 Sources / Tests 按你的工程实际目录换掉即可。
#
# 退出码：0 = 无违规（或 --fix 已执行完毕）；1 = 存在违规；2 = 用法错误
#
# 注意：--fix 属正文 4.0 定义的纯格式变更（只新增头部行），仍应与逻辑改动分开提交。

set -uo pipefail

usage() { sed -n '/^# 用法：$/,/^[^#]/p' "$0" | sed 's/^# \{0,1\}//'; }

FIX=0
QUIET=0
COPYRIGHT=""
DIRS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --fix) FIX=1 ;;
    --check) FIX=0 ;;   # 显式只读（只读本就是默认），便于在 CI 里声明意图
    --quiet) QUIET=1 ;;
    --copyright)
      [ $# -ge 2 ] || { echo "用法错误：--copyright 需要一个参数。" >&2; exit 2; }
      COPYRIGHT="$2"; shift ;;
    -*) echo "未知选项：$1" >&2; usage >&2; exit 2 ;;
    *) DIRS="$DIRS $1" ;;
  esac
  shift
done

if [ -z "${DIRS# }" ]; then
  echo "用法错误：至少需要一个目录参数。" >&2
  usage >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# awk 检查主体：所有文件一次交给单进程（200 文件规模逐文件 fork awk 要几十秒，
# 单进程个位数秒，实测同 verify_member_spacing.sh）。逐文件状态在 FNR==1 重置。
# ---------------------------------------------------------------------------
AWK_PROG='
BEGIN { inited = 0 }
function rtrim(s) { sub(/[[:space:]]+$/, "", s); return s }

# rep 与 check_file 一律用 cfname/cfbase，不能用 FILENAME/base：
# 检查推迟到「下一个文件首行」才执行，那时 FILENAME 已换成下一个文件，
# 直接用会把上一个文件的违规挂到下一个文件名下（实测踩过这个坑）。
function rep(line, msg) {
  printf "%s:%d: %s\n", cfname, line, msg > hitsfile
  hits++
}

FNR == 1 {
  if (inited) check_file()
  inited = 1
  split("", L)          # 清空行缓冲（比 delete 数组更可移植）
  n = 0
  cfname = FILENAME
  cfbase = FILENAME
  sub(/.*\//, "", cfbase)
}
FNR <= 12 { n++; L[n] = rtrim($0) }
END { if (inited) check_file() }

function check_file(   i, rest, body) {
  if (n == 0) { rep(1, "文件为空，缺文件头"); return }
  if (L[1] !~ /^\/\//) { rep(1, "缺文件头（首行不是 // 注释；--fix 可补结构）"); return }

  # 第 2 行：文件名行，必须与磁盘文件名一致（两个空格）
  if (n < 2 || L[2] != ("//  " cfbase))
    rep(2, "文件名行应为 \"//  " cfbase "\"，实际: " ((n < 2) ? "<无>" : L[2]))

  # 第 3 行：项目名行，非空；TODO 占位视同未填
  if (n < 3 || L[3] !~ /^\/\/  .+$/)
    rep(3, "缺项目名行（应为 \"//  <项目名>\"）")
  else if (index(L[3], "TODO") > 0)
    rep(3, "项目名为 TODO 占位，需人工补写")

  # 第 4 行：分隔行
  if (n < 4 || L[4] != "//")
    rep(4, "缺分隔行（应为单独一行 \"//\"）")

  # 第 5 行：Created by … on yyyy/M/d. —— 查结构不查创建者与日期数值
  if (n < 5 || L[5] !~ /^\/\/  Created by .+ on [0-9][0-9][0-9][0-9]\/[0-9]?[0-9]\/[0-9]?[0-9]\.$/)
    rep(5, "Created by 行缺失或格式不对（应为 \"//  Created by <创建者> on yyyy/M/d.\"）")

  # 第 6 行：Copyright 行；--copyright 传参后严校主体
  if (n < 6 || L[6] !~ /^\/\/  Copyright © [0-9][0-9][0-9][0-9] .+ All rights reserved\.$/) {
    rep(6, "Copyright 行缺失或格式不对（应为 \"//  Copyright © yyyy <主体>. All rights reserved.\"）")
  } else if (index(L[6], "TODO") > 0) {
    rep(6, "版权主体为 TODO 占位，需人工补写")
  } else if (copyright != "") {
    rest = L[6]
    sub(/^\/\/  Copyright © [0-9][0-9][0-9][0-9] /, "", rest)
    if (rest != copyright)
      rep(6, "版权主体不符：期望 \"" copyright "\"，实际 \"" rest "\"")
  }

  # 第 7 行：分隔行
  if (n < 7 || L[7] != "//")
    rep(7, "缺分隔行（应为单独一行 \"//\"）")

  # 第 8 行：文件作用行 —— 存在、非空、非 TODO 占位
  if (n < 8 || L[8] !~ /^\/\/  文件作用：.+/) {
    rep(8, "缺「文件作用：」行（应为 \"//  文件作用：<一句话>\"）")
  } else {
    body = L[8]
    sub(/^\/\/  文件作用：/, "", body)
    if (index(body, "TODO") > 0)
      rep(8, "「文件作用」为 TODO 占位，需人工补写")
  }
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

[ "$QUIET" -eq 0 ] && { echo "检查文件头（判据见脚本头部）"; echo "扫描 $N_FILES 个 .swift 文件"; echo; }

# ---------------------------------------------------------------------------
# --fix：只处理「整块缺失」（首行不是 // 注释）的文件；已有注释头的跳过不修。
# 纯 shell 实现（补头 = 前置 8 行 + 空行），不需要 awk 改写。
# ---------------------------------------------------------------------------
CHANGED=0
SKIPPED=0
if [ "$FIX" -eq 1 ]; then
  CREATOR="$(dscl . -read "/Users/$USER" RealName 2>/dev/null | sed 's/^RealName: *//' | tr -d '\n')"
  [ -n "$CREATOR" ] || CREATOR="$(id -un)"
  TODAY="$(date +%Y/%m/%d | sed 's|/0|/|g')"
  YEAR="$(date +%Y)"
  for f in "${FILES_A[@]}"; do
    FIRST="$(head -n 1 "$f")"
    case "$FIRST" in
      "//"*)
        SKIPPED=$((SKIPPED + 1))   # 已有注释头：结构不完整也只能人工修，不覆盖
        continue
        ;;
    esac
    PROJ="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)"
    PROJ="${PROJ##*/}"
    [ -n "$PROJ" ] || PROJ="TODO（项目名）"
    if [ -n "$COPYRIGHT" ]; then
      CP_LINE="//  Copyright © ${YEAR} ${COPYRIGHT}"
    else
      CP_LINE="//  Copyright © ${YEAR} TODO（版权主体）. All rights reserved."
    fi
    TMP="$(mktemp)"
    {
      printf '//\n//  %s\n//  %s\n//\n//  Created by %s on %s.\n%s\n//\n//  文件作用：TODO（需人工补写）\n\n' \
        "${f##*/}" "$PROJ" "$CREATOR" "$TODAY" "$CP_LINE"
      cat "$f"
    } > "$TMP"
    cat "$TMP" > "$f"          # 原地覆盖，保留原文件 inode 与权限
    rm -f "$TMP"
    CHANGED=$((CHANGED + 1))
  done
fi

if [ "$FIX" -eq 0 ]; then
  awk -v hitsfile="$ALL_HITS" -v copyright="$COPYRIGHT" "$AWK_PROG" "${FILES_A[@]}" > /dev/null
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
if [ "$FIX" -eq 1 ]; then
  echo "已补标准头 $CHANGED 个文件，跳过 $SKIPPED 个已有注释头的文件（结构不完整需人工修）"
  echo "注意：「文件作用：TODO（需人工补写）」仍会被 --check 计为违规，直到人工补写 —— 有意为之。"
  echo "复查：bash \"$0\" ${DIRS# } --quiet"
  exit 0
fi
echo "文件头违规：$N_HITS 处，涉及 $N_HIT_FILES 个文件（共扫描 $N_FILES 个）"

if [ "$N_HITS" -gt 0 ]; then
  echo
  echo "整改：缺整块头的文件可机械补齐（--fix 只补结构，作用行留 TODO）："
  echo "  bash \"$0\" ${DIRS# } --fix"
  echo "已有注释头但结构不完整的，请对照正文 4.10 人工修正（脚本不覆盖别人的头）。"
  exit 1
fi
echo "结论：文件头全部符合 4.10。"
exit 0
