#!/usr/bin/env bash
#
# fetch_official_sources.sh —— 官方规范快照的刷新与巡检工具
#
# 重要定位：**官方规范随 skill 一起分发（内置于 references/official/），
#           本脚本不是集成步骤，而是维护者主动刷新快照时才用的工具。**
#           集成后要做的离线自检请用 verify_citations.sh。
#
# 为什么不把「集成时自动下载」当默认策略：
#   1. 快照的价值在于**版本确定** —— 同一 skill 版本必须对应同一份规范文本，
#      否则「引文逐字可检索」这条纪律在不同机器上结果不一致，规范失去可复现性。
#   2. 网络不可靠。实测 raw.githubusercontent.com 存在整段时间的连接失败与挂起，
#      一次失败的下载会让快照缺文件（集成不该引入这种失败模式）。
#   3. 体积成本极低（4 个文件合计约 166 KB），随 skill 分发没有任何负担。
#   4. 受限网络/CI 常直接封禁该域名，集成时联网在很多环境下根本不可行。
#
# 下载目标恒为「本脚本所属 skill 的 references/official/」，
# 即与 SKILL.md 同级的目录。skill 被复制或移动后路径自动跟随，引用不会断。
#
# 用法：
#   bash fetch_official_sources.sh --status     # 离线：查看快照哈希、体积、抓取时间
#   bash fetch_official_sources.sh --freshness  # 联网：对比上游与本地，判断快照是否过期
#   bash fetch_official_sources.sh --check      # 联网：只校验各源是否可达，不写文件
#   bash fetch_official_sources.sh              # 联网：重新抓取全部快照（刷新 bundle）
#   bash fetch_official_sources.sh --missing    # 联网：只补缺失/损坏的文件
#
# 退出码：0 成功；1 有源不可达或 --freshness 发现上游已变更

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$SKILL_DIR/references/official"
MANIFEST="$OUT_DIR/.fetch-manifest.tsv"

MODE="fetch"
ONLY_MISSING=0
while [ $# -gt 0 ]; do
  case "$1" in
    --missing)   MODE="fetch";     ONLY_MISSING=1; shift ;;
    --check)     MODE="check";     shift ;;
    --status)    MODE="status";    shift ;;
    --freshness) MODE="freshness"; shift ;;
    "")          shift ;;
    *) echo "未知参数：$1（可用：--missing / --check / --status / --freshness）" >&2; exit 2 ;;
  esac
done

# 可用性下限：官方文档不可能小于 2KB，小于此值视为错误页 / 半截文件
MIN_BYTES=2000

# id|文件名|原始地址[|本地标注头行数]
#
# 第 4 列（可选，默认 0）用于带本地来源标注的快照：抓取时必须把标注头重新补回去，
# 比对时必须先剥离，否则 --freshness 会因为「永远对不上」而持续误报上游已更新。
SOURCES=(
  "s1|s1-api-design-guidelines.md|https://raw.githubusercontent.com/swiftlang/swift-org-website/main/documentation/api-design-guidelines/index.md"
  "s3|s3-swift-format-configuration.md|https://raw.githubusercontent.com/swiftlang/swift-format/main/Documentation/Configuration.md"
  "s4|s4-stdlib-programmers-manual.md|https://raw.githubusercontent.com/swiftlang/swift/main/docs/StandardLibraryProgrammersManual.md"
  "s5|s5-google-swift-style-guide.md|https://raw.githubusercontent.com/google/swift/gh-pages/index.md"
  # S6 是行业参考（LinkedIn），不是 Swift 官方文档；许可为 CC BY 4.0。
  # 注意：上游默认分支是 master，不是 main（main 实测 404）。
  # 末尾 11 = 本地来源标注头行数（见 emit_local_header）。
  "s6|s6-linkedin-swift-style-guide.md|https://raw.githubusercontent.com/linkedin/swift-style-guide/master/README.md|11"
)

# 本地来源标注头：S6 是第三方文本，重分发必须保留归属与许可。
# 抓取时由本函数重新生成，保证刷新不会丢掉标注。
emit_local_header() {
  case "$1" in
    s6)
      cat <<'EOF'
<!--
  来源：LinkedIn Swift Style Guide
  上游：https://github.com/linkedin/swift-style-guide （本地参考副本）
  抓取：2026-09-10（自本地 clone，commit 9e7377c）
  许可：CC BY 4.0 —— Ⓒ LinkedIn Corporation 2016
  定位：**行业参考，非 Apple / Swift 官方文档。** 本规范仅在 S1/S3/S5 未覆盖处参考它，
        且与其存在若干明确冲突（见 references/official/SOURCES.md 的「S6 冲突与取舍」表）。
        冲突时一律以 S1 / S3 为准。
  说明：以下正文为逐字原文，未作改动；请勿手工编辑本文件。
-->

EOF
      ;;
  esac
}

# 剥离本地标注头后的正文（用于与上游逐字比对）
strip_header() {
  local path="$1" hdr="$2"
  if [ "${hdr:-0}" -gt 0 ]; then
    tail -n "+$((hdr + 1))" "$path"
  else
    cat "$path"
  fi
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "unavailable"
  fi
}

file_bytes() { wc -c < "$1" 2>/dev/null | tr -d ' '; }

usable() {
  # 文件存在且体积合理
  [ -f "$1" ] || return 1
  local b; b="$(file_bytes "$1")"
  [ -n "$b" ] && [ "$b" -ge "$MIN_BYTES" ]
}

# 网络参数：--connect-timeout 是关键 —— 部分代理环境下连接阶段会长时间挂住，
# 只有总时限（--max-time）而没有连接时限时，单次请求可能远超预期。
CONNECT_TIMEOUT="${UG_FETCH_CONNECT_TIMEOUT:-8}"
REQ_TIMEOUT="${UG_FETCH_MAX_TIME:-30}"

probe() {
  # 返回 "HTTP码 字节数"；失败返回 "000 0"
  curl -sS --connect-timeout "$CONNECT_TIMEOUT" --retry 1 --retry-delay 1 \
       --max-time "$REQ_TIMEOUT" -L \
       -o /dev/null -w '%{http_code} %{size_download}' "$1" 2>/dev/null \
    || echo "000 0"
}

# 从既有清单里取出某文件上次的抓取时间（没有则返回 unknown）
known_time() {
  local file="$1"
  [ -f "$MANIFEST" ] || { echo "unknown"; return; }
  local t
  t="$(awk -F'\t' -v f="$file" '$2==f {print $4}' "$MANIFEST" | tail -1)"
  [ -n "${t:-}" ] && echo "$t" || echo "unknown"
}

# 本轮实际下载过的时间，写入 $FETCHED_TIMES（file<TAB>time）。
# 必要性：清单若一律沿用旧时间，重新抓取过的文件会显示过期的时间戳，
# 使「快照是否新鲜」这一判断失效。
FETCHED_TIMES="$(mktemp)"
trap 'rm -f "$FETCHED_TIMES"' EXIT

record_time() {
  printf '%s\t%s\n' "$2" "$1" >> "$FETCHED_TIMES"
}

fresh_time() {
  # 本轮抓过就用本轮时间，否则沿用清单里的历史时间
  local t
  t="$(awk -F'\t' -v f="$1" '$1==f {print $2}' "$FETCHED_TIMES" | tail -1)"
  if [ -n "${t:-}" ]; then echo "$t"; else known_time "$1"; fi
}

# 依据磁盘真实状态重建清单，保证清单与实际快照永远一致
rebuild_manifest() {
  local tmp; tmp="$(mktemp)"
  for entry in "${SOURCES[@]}"; do
    # 必须显式读第 4 列：只写 3 个变量时，最后一个变量会把 "url|hdr" 整段吃掉
    IFS='|' read -r id file url hdr <<< "$entry"
    local dest="$OUT_DIR/$file"
    usable "$dest" || continue
    printf "%s\t%s\t%s\t%s\t%s\n" \
      "$id" "$file" "$(file_bytes "$dest")" "$(fresh_time "$file")" "$url" >> "$tmp"
  done
  mv "$tmp" "$MANIFEST"
}

# ---------------------------------------------------------------- --status
if [ "$MODE" = "status" ]; then
  echo "本地快照状态：$OUT_DIR"
  echo
  if [ ! -f "$MANIFEST" ]; then
    echo "  尚无清单。运行 bash fetch_official_sources.sh 生成。"
    exit 0
  fi
  printf "%-4s %-36s %-9s %-19s %s\n" "ID" "文件" "字节" "抓取时间(UTC)" "sha256(前12)"
  printf "%-4s %-36s %-9s %-19s %s\n" "----" "------------------------------------" "---------" "-------------------" "-------------"
  while IFS=$'\t' read -r id file bytes fetched url; do
    [ -z "${id:-}" ] && continue
    if usable "$OUT_DIR/$file"; then
      printf "%-4s %-36s %-9s %-19s %s\n" "$id" "$file" "$bytes" "$fetched" "$(sha256_of "$OUT_DIR/$file" | cut -c1-12)"
    else
      printf "%-4s %-36s %-9s %-19s %s\n" "$id" "$file" "缺失" "-" "-"
    fi
  done < "$MANIFEST"
  echo
  echo "校验本地快照是否被篡改或损坏：重新抓取后用 sha256 比对。"
  exit 0
fi

# ---------------------------------------------------------------- --check
if [ "$MODE" = "check" ]; then
  echo "校验官方源可达性（不写入任何文件）"
  echo
  fail=0
  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r id file url hdr <<< "$entry"
    read -r code bytes <<< "$(probe "$url")"
    if [ "$code" = "200" ]; then
      printf "  [ OK ] %-4s %8s B   %s\n" "$id" "$bytes" "${url#https://raw.githubusercontent.com/}"
    else
      printf "  [FAIL] %-4s HTTP %-4s   %s\n" "$id" "$code" "$url"
      fail=1
    fi
  done
  echo
  if [ "$fail" -eq 0 ]; then
    echo "全部可达。"
  else
    echo "存在不可达的源。若为网络/代理限制，属预期；请使用既有本地快照（--status 查看）。"
  fi
  exit "$fail"
fi

# ---------------------------------------------------------------- --freshness
# 快照内置于 skill，天然有「滞后于上游」的风险。本模式把这个风险变成可检测的：
# 联网取回上游内容，与本地快照逐字节比对，只报告、不修改。
if [ "$MODE" = "freshness" ]; then
  echo "对比上游与本地快照（只报告，不修改任何文件）"
  echo
  tmp="$(mktemp)"
  tmp_local="$(mktemp)"
  stale=0
  unreachable=0

  printf "%-4s %-36s %s\n" "ID" "文件" "结论"
  printf "%-4s %-36s %s\n" "----" "------------------------------------" "------------------------------"

  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r id file url hdr <<< "$entry"
    dest="$OUT_DIR/$file"

    if ! curl -sS --connect-timeout "$CONNECT_TIMEOUT" --retry 2 --retry-delay 1 \
              --max-time "$REQ_TIMEOUT" -f -L -o "$tmp" "$url" 2>/dev/null; then
      printf "%-4s %-36s %s\n" "$id" "$file" "无法获取上游（网络问题）"
      unreachable=1
      continue
    fi

    # 本地快照可能带来源标注头（S6），比对前必须先剥离，否则永远对不上
    strip_header "$dest" "${hdr:-0}" > "$tmp_local" 2>/dev/null || : > "$tmp_local"
    local_hash="$(sha256_of "$tmp_local")"
    remote_hash="$(sha256_of "$tmp")"

    if [ ! -f "$dest" ]; then
      printf "%-4s %-36s %s\n" "$id" "$file" "本地缺失"
      stale=1
    elif [ "$local_hash" = "$remote_hash" ]; then
      printf "%-4s %-36s %s\n" "$id" "$file" "一致 ${remote_hash:0:12}"
    else
      printf "%-4s %-36s %s\n" "$id" "$file" "上游已更新（本地 ${local_hash:0:12} / 上游 ${remote_hash:0:12}）"
      stale=1
    fi
  done

  rm -f "$tmp" "$tmp_local"
  echo
  if [ "$unreachable" -eq 1 ]; then
    echo "部分源无法访问，结论不完整。这不影响快照本身可用 —— 快照已随 skill 内置。"
  fi
  if [ "$stale" -eq 1 ]; then
    cat <<'EOF'
发现上游变更或本地缺失。处理建议：
  1. 先看差异是否影响规范正文的引用：更新后跑 bash verify_citations.sh；
  2. 确认需要跟进时，才执行 bash fetch_official_sources.sh 刷新快照；
  3. 刷新属于规范依据的变更，应记入 references/swift-coding-standards.md 附录 C 变更记录。
EOF
    exit 1
  fi
  echo "本地快照与上游一致，未发现过期。"
  exit 0
fi

# ---------------------------------------------------------------- fetch
mkdir -p "$OUT_DIR"

if [ "$ONLY_MISSING" -eq 1 ]; then
  echo "补齐缺失的官方规范快照 -> $OUT_DIR"
else
  echo "抓取官方规范快照 -> $OUT_DIR"
fi
echo

fail=0
attempted=0

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r id file url hdr <<< "$entry"
  dest="$OUT_DIR/$file"

  # --missing：已就绪的直接跳过，不产生网络请求
  if [ "$ONLY_MISSING" -eq 1 ] && usable "$dest"; then
    printf "  [SKIP] %-4s 已就绪（%s B）\n" "$id" "$(file_bytes "$dest")"
    continue
  fi

  attempted=$((attempted + 1))

  # 先写临时文件，成功后再移动，避免半截文件污染快照
  body="$dest.body.tmp"
  if curl -sS --connect-timeout "$CONNECT_TIMEOUT" --retry 2 --retry-delay 1 \
          --max-time "$REQ_TIMEOUT" -f -L -o "$body" "$url" 2>/dev/null; then
    body_bytes="$(file_bytes "$body")"
    if [ -z "$body_bytes" ] || [ "$body_bytes" -lt "$MIN_BYTES" ]; then
      printf "  [SKIP] %-4s 内容过小（%s B），疑似错误页，保留旧快照\n" "$id" "${body_bytes:-0}"
      rm -f "$body"
      fail=1
      continue
    fi
    # 带本地来源标注的快照（S6）：必须把标注头补回去，
    # 否则刷新一次就会静默丢掉归属与许可信息。
    if [ "${hdr:-0}" -gt 0 ]; then
      { emit_local_header "$id"; cat "$body"; } > "$body.hdr" && mv "$body.hdr" "$body"
    fi
    mv "$body" "$dest"
    record_time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$file"
    printf "  [ OK ] %-4s %8s B（正文 %s B）  %s\n" \
      "$id" "$(file_bytes "$dest")" "$body_bytes" "$file"
  else
    rm -f "$body" "$body.hdr"
    if usable "$dest"; then
      printf "  [FAIL] %-4s 下载失败，沿用旧快照（%s B）\n" "$id" "$(file_bytes "$dest")"
    else
      printf "  [FAIL] %-4s 下载失败，且无可用旧快照\n" "$id"
    fi
    fail=1
  fi
done

rm -f "$OUT_DIR"/*.tmp 2>/dev/null

# 清单始终依据磁盘真实状态重建，避免与快照不一致
rebuild_manifest

echo
if [ "$fail" -eq 0 ]; then
  echo "快照完成，清单：references/official/.fetch-manifest.tsv"
  if [ "$attempted" -eq 0 ]; then
    echo "（未发起任何下载：目标快照均已就绪）"
  fi
  echo "注意：官方源会更新。原始文本以官网为准，本标准正文为转述。"
else
  echo "部分源未成功，已在可能的情况下沿用旧快照；清单已按磁盘实际状态刷新。"
  echo "可先 --check 判断是网络问题还是上游变更。"
fi

exit "$fail"
