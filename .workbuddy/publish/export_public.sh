#!/usr/bin/env bash
#
# export_public.sh —— 从正身生成「可公开发布」的 skill 树（白名单导出）
#
# 为什么需要它：
#   对外要提供**可下载即用**的 skill，但不想外露「如何设计 / 如何迭代」。
#   而这件事**不能靠手工删** —— 手工删出的第二份副本会与正身静默分叉
#   （本工程历史上最痛的一类事故：改了半天没人读，且无任何报错）。
#   正身永远是唯一真源，发布树是**可重复生成的构建产物**。
#
# 剥离三类内容：
#   ① 三个维护者脚本：verify_consistency.sh / verify_citations.sh / fetch_official_sources.sh
#      —— 使用者用不到，却是「单一权威 + 期望值派生 + 逐字引文校验」的完整实现
#   ② 描述设计与迭代过程的部分：
#        SKILL.md 的「场景零 / 场景零之二」两节与三条参考文件、description 里的「引文校验」
#        references/swift-coding-standards.md 附录 C 的决策叙述（压成「版本 + 影响面」表）
#        references/official/SOURCES.md 的方案对比论证与维护者流程
#   ③ 悬空引用：指向内部文档 docs/skill-review/ 的写法
#
# 必须保留（使用者必需，不可剥）：
#   规范正文 / 注释规范 / 缺陷目录 / 命名词典 / 整改手册 / 两个配置模板 /
#   三个使用者脚本 / 权威来源快照；
#   以及 SOURCES.md 的「归属与许可」段 —— S6 是 CC BY 4.0，署名是重分发的法律要求。
#
# 用法：
#   bash export_public.sh                 # 输出到本脚本同级的 preview/
#   bash export_public.sh <输出目录>
#
# 退出码：0 = 导出且全部断言通过；1 = 断言失败（发布树不可用，勿推送）；2 = 用法错误

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="${1:-$SCRIPT_DIR/preview}"
STAMP="$OUT.stamp"

if [ ! -f "$SRC/SKILL.md" ]; then
  printf '错误：正身路径不正确，未见 %s/SKILL.md\n' "$SRC" >&2
  exit 2
fi

# 防误删：只清理「本脚本自己生成过的」输出目录（凭随附的 .stamp 标记判断）。
# 标记在**创建时就落**，而不是等断言全绿才落 —— 否则一次失败的导出会留下
# 「没有标记的生成物」，下次运行就被守卫挡住（首次实现即踩到这个）。
if [ -d "$OUT" ]; then
  if [ -f "$STAMP" ]; then
    rm -rf "$OUT"
  else
    printf '拒绝：%s 已存在，且没有本脚本的标记 %s —— 不确认它是生成物就不删。\n' "$OUT" "$STAMP" >&2
    printf '若确认它是上一次导出的残留，手工删除后重跑即可。\n' >&2
    exit 2
  fi
fi
mkdir -p "$OUT"
: > "$STAMP"

FAILS=0
ok()   { printf '  [OK]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; FAILS=$((FAILS + 1)); }
sect() { printf '\n%s\n' "$1"; }

# 执行一次 awk 变换；awk 以非 0 退出（锚点没命中）时**不覆盖原文件**，避免半成品。
# 注意：`mv` 会新建 inode，**默认权限 644** —— 必须显式恢复原模式，
# 否则脚本的 +x 位会静默丢失（首轮导出即踩到，由发布树断言抓出）。
run_awk() {
  local f="$1" desc="$2" mode; shift 2
  mode=$(stat -f '%Lp' "$f" 2>/dev/null)
  if awk "$@" "$f" > "$f.tmp" 2> "$f.err"; then
    mv "$f.tmp" "$f"
    [ -n "$mode" ] && chmod "$mode" "$f"
    rm -f "$f.err"
    ok "$desc"
  else
    bad "$desc（锚点未命中，文件未改动）"
    sed 's/^/         /' "$f.err" >&2
    rm -f "$f.tmp" "$f.err"
  fi
}

run_sed() {
  local f="$1" desc="$2" mode; shift 2
  mode=$(stat -f '%Lp' "$f" 2>/dev/null)
  if sed "$@" "$f" > "$f.tmp"; then
    mv "$f.tmp" "$f"
    [ -n "$mode" ] && chmod "$mode" "$f"
    ok "$desc"
  else
    bad "$desc"
    rm -f "$f.tmp"
  fi
}

assert_absent() { # <字面串> <说明>
  local hits
  hits=$(grep -rlF -- "$1" "$OUT" 2>/dev/null | sed "s|$OUT/||" | tr '\n' ' ')
  if [ -z "$hits" ]; then ok "已无残留：$2"; else bad "仍含「$1」：$hits"; fi
}

assert_present() { # <字面串> <说明>
  if grep -rqF -- "$1" "$OUT" 2>/dev/null; then ok "保留：$2"; else bad "缺失：$2（「$1」找不到）"; fi
}

# ---------------------------------------------------------------------------
sect '1. 按白名单复制（未列入者一律不进发布树）'
read -r -d '' FILES <<'LIST'
.gitignore
SKILL.md
assets/swift-format.json
assets/swiftlint.yml
references/swift-coding-standards.md
references/comment-standards.md
references/defect-catalog.md
references/naming-antipatterns.md
references/remediation-playbook.md
references/official/.fetch-manifest.tsv
references/official/SOURCES.md
references/official/s1-api-design-guidelines.md
references/official/s3-swift-format-configuration.md
references/official/s4-stdlib-programmers-manual.md
references/official/s5-google-swift-style-guide.md
references/official/s6-linkedin-swift-style-guide.md
scripts/bootstrap_swift_style.sh
scripts/remediate.sh
scripts/verify_member_spacing.sh
LIST

N_LIST=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ ! -f "$SRC/$f" ]; then bad "白名单文件在正身不存在：$f"; continue; fi
  mkdir -p "$OUT/$(dirname "$f")"
  cp -p "$SRC/$f" "$OUT/$f"
  N_LIST=$((N_LIST + 1))
done <<< "$FILES"
[ "$FAILS" -eq 0 ] && ok "复制 $N_LIST 个文件 → $OUT"

# ---------------------------------------------------------------------------
sect '2. SKILL.md：剥离维护者两节、三条参考文件、description 里的「引文校验」'
T="$OUT/SKILL.md"
run_awk "$T" '剥离「场景零 / 场景零之二」两节' '
  /^### 场景零：/ { skip = 1; n++ }
  /^### 场景一：/ { skip = 0 }
  !skip { print }
  END { if (n != 1) exit 9 }
'
run_awk "$T" '删除参考文件里三条维护者脚本' '
  /^- `scripts\/(verify_consistency|verify_citations|fetch_official_sources)\.sh`/ { n++; next }
  { print }
  END { if (n != 3) exit 9 }
'
run_sed "$T" 'description 去掉「与引文校验」' 's/权威来源离线快照与引文校验/权威来源离线快照/'

# ---------------------------------------------------------------------------
sect '3. 规范正文：剥离 1.2 的脚本调用块、压掉附录 C 的决策叙述'
M="$OUT/references/swift-coding-standards.md"
run_awk "$M" '删除 1.2 节的维护者脚本调用块' '
  { L[NR] = $0 }
  END {
    for (i = 1; i <= NR; i++) {
      if (skip) { if (L[i] == "```") { skip = 0; n++ } ; continue }
      if (L[i] == "```bash" && L[i+1] == "# 集成后自检（纯离线，秒级）") { skip = 1; continue }
      print L[i]
    }
    if (n != 1) exit 9
  }
'
run_sed "$M" '引文纪律句去掉脚本名' 's/，由 `verify_citations\.sh` 强制检查//'
run_awk "$M" '截断附录 C 的决策叙述（保留标题）' '
  /^## 附录 C 变更记录/ { print; stop = 1; n++ }
  !stop { print }
  END { if (n != 1) exit 9 }
'

cat >> "$M" <<'MD'

| 版本 | 日期 | 影响面 |
| --- | --- | --- |
| v1.0 | 2026-09-10 | 首版：第 3–5 章（命名 / 格式 / 语言约束）、第 7 章工具链、第 8 章迁移策略 |
| v1.1 | 2026-09-10 | 1.2 新增「官方依据的离线快照与引文纪律」；修正 S4 来源地址；3.3 调整 `get` 前缀的定性 |
| v1.2 | 2026-09-10 | 1.2 明确快照内置分发；8.1 补充两条计数注意；新增 `references/remediation-playbook.md` 与 `scripts/remediate.sh` |
| v1.3 | 2026-09-10 | 3.1 收敛命名判据；3.3.5 取消分词约束；3.7 精简测试命名；新增 4.0、5.8、5.9、5.10；第 0 章改为 16 类缺陷；新增 1.3 冲突取舍表、`references/comment-standards.md`、`references/defect-catalog.md` |
| v1.4 | 2026-09-10 | 4.5 / 4.6 缩进与行长改为 2 空格 / 100 列，1.3 同步；8.2 增补一条前提检查；同步两个模板资产 |
| v1.5 | 2026-09-11 | 4.5 / 4.6 改为每层 4 空格 / 120 列并开启两个缩进开关，**取代 v1.4 的取值**；同步模板资产与 `SKILL.md` |
| v1.5.1 | 2026-09-11 | 修正正文版本表、8.2 的迁移方向、4.6 的续行缩进；修正 `references/naming-antipatterns.md` 与 `references/remediation-playbook.md` 的规则名与验收条数 |
| v1.5.2 | 2026-09-11 | 3.5 补 `i` / `j` 豁免与「与工具对齐」说明；5.8 与验收清单统一类型体量上限为 300 行；5.1 补三条 force 类规则的分工说明 |
| v1.5.3 | 2026-09-11 | `scripts/remediate.sh` 的目录清单改为数组；缺配置时自动生成并改写 `included`；统一词表的出处 |
| v1.5.4 | 2026-09-11 | 压缩 `SKILL.md` 的 `description`；`scripts/remediate.sh` 采集改为按阶段缓存；扩大正文引文的校验范围；修复 `/bin/bash` 3.2 的兼容性 |
| v1.5.5 | 2026-09-11 | 4.0 / 4.7 拆分「成员间分隔空行」并补出处；缺陷全景表新增第 17 类；新增 `scripts/verify_member_spacing.sh` |
| v1.5.6 | 2026-09-11 | `references/remediation-playbook.md` §2 新增「第 ③ 步的补救」小节，并补一条补丁应用顺序的注意事项 |
MD
ok '附录 C 改为「版本 + 影响面」表'

# ---------------------------------------------------------------------------
sect '3b. 剥离散落在正文 / SKILL.md / 命名词典里的「修订史」叙述'
# 判据：**保留「为什么这样定」，剥离「曾经是什么 / 何时改的 / 改过几处」**。
# 这些散落注记与附录 C 同源，同等暴露迭代过程，故与附录 C 一并处理。
# （本节是发布树断言逼出来的：首轮导出时断言报「推翻 / 动因」仍在，
#   顺藤才发现在附录 C 之外还有 11 处日期式修订叙述。）
K="$OUT/SKILL.md"
run_sed "$K" '去掉 3.x 里 drain 漂移的经过' \
  's|（此前 `drain` 在词典与整改手册间漂移，根源就是多处副本）||'
run_sed "$K" '去掉缩进条目里的版本迭代说明' \
  's|（2026-09-11 决定，替代 09-10 的 2 空格 / 100 列）||'
run_sed "$M" '去掉「多处副本曾导致漂移」的叙述' \
  's| —— 多处副本曾导致 `drain` 在词典与整改手册间漂移（2026-09-11 修正）。|。|'
run_sed "$M" '去掉 3.5 的日期' 's|与工具对齐（2026-09-11）|与工具对齐|'
run_sed "$M" '去掉 5.1 的日期' 's|分工（2026-09-11 明确）|分工|'
run_sed "$M" '4.5 注记改为「只讲取值理由」' \
  's|> 2026-09-11 由 2 空格调整为 4 空格（推翻 v1.4 的 2/100 决定）。动因：Xcode 编辑器默认缩进步长就是 4 空格|> 取值理由：Xcode 编辑器默认缩进步长就是 4 空格|'
run_sed "$M" '去掉 #if 条目的修订说明' \
  's|（旧模板设过 `false`，与 Xcode 行为相反，2026-09-11 修正）|（集成旧模板时别把 `false` 带进来 —— 那样与 Xcode 行为相反）|'
run_sed "$M" '去掉第 0 章的「新增」叙述' \
  's|第 17 类为 2026-09-11 新增，实测值为当日在 202 个源文件上重扫所得。|第 17 类的实测值取自 202 个源文件的重扫。|'
run_sed "$M" '去掉 1.3 表格里的调整说明' \
  's|120 配合 4 空格缩进（2026-09-11 调整，见附录 C v1.5）|120 配合 4 空格缩进|'
run_sed "$OUT/references/naming-antipatterns.md" '去掉词典里 drain 的归类变更叙述' \
  's|`drain`（排空队列 / 迭代器）原属借喻类，2026-09-11 移入「默认不动」|`drain`（排空队列 / 迭代器）属「默认不动」|'
# 使用者脚本头部也带着内部评审编号与修订叙述（首轮断言没查到这里，靠 grep 评审编号才发现）。
# 保留技术理由（对使用者有用），去掉评审编号与「改为 / 此前」的迭代叙述。
# 注意 getline 的次数 = 注释**除首行外**的行数。此处注释只占 2 行，故只 getline 一次；
# 多吃一行会把紧随其后的 `if [ -n "$DIRS" ]; then` 一起删掉 —— 首版就是这样
# 把脚本改成语法错误的（断言没抓出，靠 `bash -n` 独立核验才发现）。
run_awk "$OUT/scripts/remediate.sh" '去掉 remediate.sh 头部的评审编号与修订叙述' '
  /^# C[0-9]+（2026-/ {
    print "# 目录清单用数组而非字符串：`$DIRS` 不加引号展开时，路径含空格会被二次切分；"
    print "# 数组展开 \"${DIRS_A[@]}\" 无此问题。"
    getline
    n++
    next
  }
  { print }
  END { if (n != 1) exit 9 }
'
run_sed "$OUT/scripts/remediate.sh" '去掉体内注释里的评审编号' \
  's|（C4：避免路径被二次切分）|（避免路径被二次切分）|'

# ---------------------------------------------------------------------------
sect '4. SOURCES.md：剥离方案论证与维护者流程（保留许可与归属）'
S="$OUT/references/official/SOURCES.md"
run_awk "$S" '折叠「分发方式」论证为一句话，并删除「使用方式 / 过期流程 / 引文纪律」三节' '
  /^## 分发方式/ {
    skip = 1; n++
    print "快照文件**直接内置**在本目录，随 skill 一起分发：集成、复制、移动到任何位置都无需联网，引用关系也不会断。"
    print ""
    next
  }
  /^## 归属与许可/ { skip = 0 }
  !skip { print }
  END { if (n != 1) exit 9 }
'

# ---------------------------------------------------------------------------
sect '5. 整改手册：终检命令块里去掉维护者脚本'
P="$OUT/references/remediation-playbook.md"
run_awk "$P" '删除终检命令块里的 verify_citations 行' '
  /^bash <skill-dir>\/scripts\/verify_citations\.sh/ { n++; next }
  { print }
  END { if (n != 1) exit 9 }
'

# ---------------------------------------------------------------------------
sect '6. 发布树断言'

N_REAL=$(cd "$OUT" && find . -type f | grep -c .)
if [ "$N_REAL" = "$N_LIST" ]; then ok "文件数 $N_REAL 与白名单一致"; else bad "文件数 $N_REAL ≠ 白名单 $N_LIST"; fi

if find "$OUT" -name '.workbuddy' -o -name '.DS_Store' | grep -q .; then
  bad '发布树里出现 .workbuddy / .DS_Store'
else
  ok '无 .workbuddy / .DS_Store'
fi

assert_absent 'verify_consistency'   '维护者脚本 verify_consistency.sh 的引用'
assert_absent 'verify_citations'     '维护者脚本 verify_citations.sh 的引用'
assert_absent 'fetch_official_sources' '维护者脚本 fetch_official_sources.sh 的引用'
assert_absent 'docs/skill-review'    '指向内部文档 docs/skill-review/ 的悬空引用'
assert_absent '按用户定夺'            '决策叙述（按用户定夺）'
assert_absent '推翻'                  '决策叙述（推翻）'
assert_absent '动因'                  '决策叙述（动因）'
assert_absent '曾导致'                '决策叙述（曾导致）'
assert_absent '复审'                  '决策叙述（复审）'
assert_absent '起因'                  '决策叙述（起因）'
assert_absent '### 场景零'            'SKILL.md 面向维护者的两节'
# 注意：「此前」不作为禁词。verify_member_spacing.sh 头部用它解释「这条规则为什么需要
#   一个专门的检查器」（面向使用者的存在理由，非迭代史），属**有意保留**的用法。
#   禁词只收真·内部痕迹：评审编号、内部文档路径、修订动词。

# 内部评审编号（C4 / D3 之类）与内部文档路径。
# 模式刻意只用 ASCII 字符类：全角字符放进 `[...]` 时 BSD grep 的行为不可靠
# （首版把 `（C4：…）` 写成 `[（(][CD][0-9]+[（(]`，实测在 `grep -r` 与 stdin 下结论不一致）。
# 前后各加一个「非标识符字符」的边界，避免把 shellcheck 的 SC2206 判成评审编号。
REVIEW_PAT='(^|[^0-9A-Za-z_])[CD][0-9]+([^0-9A-Za-z_]|$)|P0 清单|skill-review'
REV=$(grep -rEl "$REVIEW_PAT" "$OUT" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REV" = "0" ]; then
  ok '无内部评审编号 / 内部文档路径'
else
  bad "仍有 $REV 个文件含评审编号：$(grep -rEl "$REVIEW_PAT" "$OUT" | sed "s|$OUT/||" | tr '\n' ' ')"
fi

# 附录 C 压缩表的规模：应恰为 12 行版本记录
N_VER=$(grep -c '^| v1\.' "$M")
if [ "$N_VER" = "12" ]; then ok "附录 C 版本行 12 条"; else bad "附录 C 版本行应为 12 条，实际 $N_VER"; fi

# 结构性断言：任何「日期 + 修订动词」的写法都视为迭代叙述残留。
# 附录 C 的版本表里日期后紧跟 ` | `，故用 [^|] 限定不得跨列 —— 表本身不该被判为违规。
NARR_PAT='2026-09-[0-9]{2}[^|]{0,6}(修正|调整|决定|明确|新增|移入|替代|推翻|改为)'
NARR=$(grep -rEl "$NARR_PAT" "$OUT" 2>/dev/null | wc -l | tr -d ' ')
if [ "$NARR" = "0" ]; then
  ok '无「日期 + 修订动词」式的迭代叙述'
else
  bad "仍有 $NARR 个文件含日期式修订叙述：$(grep -rEl "$NARR_PAT" "$OUT" | sed "s|$OUT/||" | tr '\n' ' ')"
fi

assert_present '## 归属与许可'        'SOURCES.md 的归属与许可段（重分发的法律要求）'
assert_present 'CC BY 4.0'            'S6 的许可声明'
assert_present '## 附录 C 变更记录'    '版本沿革表的位置（正文与手册有多处引用它）'
assert_present 'scripts/verify_member_spacing.sh' '使用者脚本仍被文档引用'

# 版本号：发布树内部保持单一事实来源（版本表 == 附录 C 末行）
V_HEAD=$(awk -F'|' '/^\| *版本 *\|/ { gsub(/[[:space:]]/, "", $3); print $3 }' "$M" | head -1)
V_TAIL=$(grep -oE '^\| v[0-9]+\.[0-9]+(\.[0-9]+)? ' "$M" | tail -1 | tr -d '| ')
V_SRC=$(awk -F'|' '/^\| *版本 *\|/ { gsub(/[[:space:]]/, "", $3); print $3 }' "$SRC/references/swift-coding-standards.md" | head -1)
if [ "$V_HEAD" = "$V_TAIL" ]; then ok "版本表 $V_HEAD == 附录 C 末行 $V_TAIL"; else bad "版本表 $V_HEAD ≠ 附录 C 末行 $V_TAIL"; fi
if [ "$V_HEAD" = "$V_SRC" ]; then ok "发布树版本 $V_HEAD == 正身版本 $V_SRC"; else bad "发布树版本 $V_HEAD ≠ 正身版本 $V_SRC"; fi

for s in bootstrap_swift_style.sh remediate.sh verify_member_spacing.sh; do
  if [ -x "$OUT/scripts/$s" ]; then ok "可执行位保留：scripts/$s"; else bad "丢失可执行位：scripts/$s"; fi
done

# 内容类断言查不出「脚本被改坏」。必须独立跑一次语法检查 ——
# 这条是首版漏掉的：awk 多吃一行删掉了 `if ... then`，断言全绿但脚本已无法运行。
for f in "$OUT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "语法通过：scripts/$(basename "$f")"; else bad "语法错误：scripts/$(basename "$f")"; fi
done

# ---------------------------------------------------------------------------
printf '\n──────────── 汇总 ────────────\n'
printf '正身 : %s\n' "$SRC"
printf '发布树: %s\n' "$OUT"
printf 'FAIL: %s\n' "$FAILS"
if [ "$FAILS" -gt 0 ]; then
  printf '结论：发布树不可用，勿推送。\n'
  exit 1
fi
printf '结论：发布树就绪（未推送）。\n'
exit 0
