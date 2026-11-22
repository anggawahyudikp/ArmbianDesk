#!/usr/bin/env bash
set -euo pipefail

# T13, T14, T15 — Privacy/sanitization scan, source ZIP allowlist build, SHA-256 check, and roundtrip smoke test.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[T13] Running sanitization scan on repo..."
"$ROOT_DIR/tools/sanitize-check.sh" "$ROOT_DIR"

echo "[T14] Checking LICENSE and THIRD_PARTY_NOTICES.md presence..."
[ -f "$ROOT_DIR/LICENSE" ] || { echo "FAIL: LICENSE missing" >&2; exit 1; }
[ -f "$ROOT_DIR/THIRD_PARTY_NOTICES.md" ] || { echo "FAIL: THIRD_PARTY_NOTICES.md missing" >&2; exit 1; }

echo "[T15] Building allowlist source ZIP and running smoke tests from extracted archive..."
TMP_OUT="$(mktemp -d)"
trap 'rm -rf "$TMP_OUT"' EXIT

"$ROOT_DIR/tools/package-source.sh" "$TMP_OUT/dist"
ZIP_FILE="$TMP_OUT/dist/ArmbianDesk-0.1.0-source.zip"
(cd "$TMP_OUT/dist" && sha256sum -c "ArmbianDesk-0.1.0-source.zip.sha256")

# Ensure .git or secrets are not inside the ZIP
if unzip -l "$ZIP_FILE" | grep -Eq '(\.git/|\.stb-backups/|chromium-profile/|\.env$)'; then
    echo "FAIL: T15 forbidden path detected inside source ZIP!" >&2
    exit 1
fi

mkdir -p "$TMP_OUT/extracted"
unzip -q "$ZIP_FILE" -d "$TMP_OUT/extracted"
EXT_ROOT="$TMP_OUT/extracted/ArmbianDesk-0.1.0"

"$EXT_ROOT/tools/sanitize-check.sh" "$EXT_ROOT"
"$EXT_ROOT/tests/test_static.sh"
python3 "$EXT_ROOT/tests/test_config_parser.py"
"$EXT_ROOT/tests/test_install_lifecycle.sh"
"$EXT_ROOT/tests/test_image_builder.sh"

echo "PASS: T13, T14, T15 sanitization and extracted source ZIP smoke test passed."
