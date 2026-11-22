#!/usr/bin/env bash
set -euo pipefail

# Build a clean allowlist source ZIP + SHA-256 without .git, backups, images, or secrets.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$SELF_DIR/dist}"
VERSION="0.1.0"
ZIP_NAME="ArmbianDesk-${VERSION}-source.zip"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH" "${ZIP_PATH}.sha256"

ALLOWLIST=(
    "README.md"
    "README.id.md"
    "LICENSE"
    "THIRD_PARTY_NOTICES.md"
    "CHANGELOG.md"
    "CONTRIBUTING.md"
    "SECURITY.md"
    "DECISIONS.md"
    "TEST_REPORT.md"
    "BENCHMARK.md"
    "RELEASE_CHECKLIST.md"
    ".gitignore"
    ".github/workflows/ci.yml"
    "bin"
    "lib"
    "config"
    "share"
    "docs"
    "tools"
    "tests"
)

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

PKG_ROOT="$STAGE_DIR/ArmbianDesk-${VERSION}"
mkdir -p "$PKG_ROOT"

for item in "${ALLOWLIST[@]}"; do
    src="$SELF_DIR/$item"
    [ -e "$src" ] || { echo "error: allowlisted path missing: $item" >&2; exit 1; }
    mkdir -p "$(dirname "$PKG_ROOT/$item")"
    cp -a "$src" "$PKG_ROOT/$item"
done

# Strip any transient caches from staged tree
find "$PKG_ROOT" \( -name '__pycache__' -o -name '*.pyc' -o -name '*.tmp' -o -name '*.log' \) -exec rm -rf {} +

"$SELF_DIR/tools/sanitize-check.sh" "$PKG_ROOT"

(
    cd "$STAGE_DIR"
    zip -rq "$ZIP_PATH" "ArmbianDesk-${VERSION}"
)

(
    cd "$OUT_DIR"
    sha256sum "$ZIP_NAME" >"${ZIP_NAME}.sha256"
)
echo "Created allowlist source ZIP: $ZIP_PATH"
cat "${ZIP_PATH}.sha256"
