#!/usr/bin/env bash
# 回归：格式工具和文件头通过，不能冒充正文注释语言已通过人工审核。
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/project/Sources"
cat > "$TMP/bin/swift" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = format ] && [ "${2:-}" = --version ]; then echo 'swift-format test'; fi
EOF
cat > "$TMP/bin/swiftlint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/swift" "$TMP/bin/swiftlint"
cat > "$TMP/project/Sources/Example.swift" <<'EOF'
//
//  Example.swift
//  Example
//
//  Created by Developer on 2026/10/21.
//  Copyright © 2026 Example. All rights reserved.
//
//  文件作用：提供状态读取示例。

/// Returns the current state.
public func state() -> Int { 1 }
EOF
bash "$SKILL_DIR/scripts/verify_file_header.sh" "$TMP/project/Sources" --quiet >/dev/null
PATH="$TMP/bin:$PATH" bash "$SKILL_DIR/scripts/remediate.sh" "$TMP/project" --check --allow-missing-config >"$TMP/output"
REPORT="$TMP/project/SWIFT_STANDARD_REPORT.md"
grep -Fq '无 SwiftLint 待处理项；仍须完成下方的正文注释人工复核。' "$REPORT"
grep -Fq -- '- [ ] 已逐个核对本次新建/修改的声明是否缺少应有的 `///` / `//`' "$REPORT"
grep -Fq 'Example.swift:10:/// Returns the current state.' "$REPORT"
grep -Fq 'verify_member_spacing.sh' "$REPORT"
grep -Fq 'verify_file_header.sh' "$REPORT"
grep -Fq '上述四条命令不检查正文注释语言与质量' "$REPORT"
! grep -Fq '整改完成' "$TMP/output"
# 仅核对有来源的本次新建文件；历史文件不按当前用户强行验作者。
if bash "$SKILL_DIR/scripts/verify_file_header.sh" "$TMP/project/Sources" --creator ugreen --check >"$TMP/creator-output"; then
  echo 'FAIL: 虚构/未核实作者不应通过显式核验' >&2
  exit 1
fi
grep -Fq '创建者不符' "$TMP/creator-output"
# 拼造作者（<项目名> Team）无需 --creator 也应被默认核验拦下。
mkdir -p "$TMP/fabricated"
cat > "$TMP/fabricated/Team.swift" <<'EOF'
//
//  Team.swift
//  Example
//
//  Created by Example Team on 2026/10/21.
//  Copyright © 2026 Example. All rights reserved.
//
//  文件作用：提供拼造作者示例。
EOF
if bash "$SKILL_DIR/scripts/verify_file_header.sh" "$TMP/fabricated" --check >"$TMP/fabricated-output" 2>&1; then
  echo 'FAIL: <项目名> Team 这类拼造作者不应通过默认核验' >&2
  exit 1
fi
grep -Fq '创建者疑似由项目名拼造' "$TMP/fabricated-output"
mkdir -p "$TMP/legacy"
printf 'import Foundation\n' >"$TMP/legacy/Legacy.swift"
bash "$SKILL_DIR/scripts/verify_file_header.sh" "$TMP/legacy" --fix --quiet >"$TMP/legacy-output"
grep -Fq 'Created by TODO（待核实创建者） on TODO.' "$TMP/legacy/Legacy.swift"
if bash "$SKILL_DIR/scripts/verify_file_header.sh" "$TMP/legacy" --check >"$TMP/legacy-check"; then
  echo 'FAIL: 不可将历史作者/日期伪装为已核实' >&2
  exit 1
fi
printf 'PASS: 虚构作者被显式核验与默认拼造判据双重拦截；历史文件保留待核实占位；正文注释附定位且仍需人工复核\n' 
