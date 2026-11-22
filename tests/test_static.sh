#!/usr/bin/env bash
set -euo pipefail

# T01 — Static & syntax validation (one file per bash -n invocation).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AD_BIN="$ROOT_DIR/bin/armbiandesk"

echo "[T01] Checking shell scripts syntax with bash -n (one per invocation)..."
shell_count=0
while IFS= read -r -d '' f; do
    bash -n "$f"
    shell_count=$((shell_count + 1))
done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/lib" "$ROOT_DIR/tools" "$ROOT_DIR/tests" -type f \( -name '*.sh' -o -path "$ROOT_DIR/bin/*" \) -print0 | sort -z)

echo "[T01] Checking executable permissions on bin/ and tools/*.sh..."
for exe in "$ROOT_DIR/bin/armbiandesk" "$ROOT_DIR/bin/armbiandesk-image" "$ROOT_DIR/tools/build-image.sh" "$ROOT_DIR/tools/flash-usb.sh" "$ROOT_DIR/tools/benchmark.sh" "$ROOT_DIR/tools/package-source.sh" "$ROOT_DIR/tools/sanitize-check.sh"; do
    [ -x "$exe" ] || { echo "FAIL: not executable: $exe" >&2; exit 1; }
done

echo "[T01] Validating XML, SVG, and .desktop files..."
python3 - "$ROOT_DIR" <<'PY'
import configparser, os, sys, xml.etree.ElementTree as ET

root = sys.argv[1]
xml_files = [
    "share/openbox/rc.xml",
    "share/openbox/menu.xml",
    "share/xfce4/xfce4-panel.xml",
    "share/xfce4/xfwm4.xml",
    "share/wallpapers/armbiandesk.svg",
]
for rel in xml_files:
    p = os.path.join(root, rel)
    ET.parse(p)

desktop_files = [
    "share/xsessions/armbiandesk.desktop",
    "share/applications/armbiandesk-browser.desktop",
    "share/applications/armbiandesk-files.desktop",
]
for rel in desktop_files:
    p = os.path.join(root, rel)
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    cp.read(p, encoding="utf-8")
    assert "Desktop Entry" in cp, f"Missing [Desktop Entry] in {rel}"
    for req in ("Type", "Name", "Exec"):
        assert req in cp["Desktop Entry"], f"Missing {req} in {rel}"
print("XML, SVG, and .desktop syntax OK.")
PY

echo "[T01] Validating example configuration..."
"$AD_BIN" config validate --file "$ROOT_DIR/config/armbiandesk.conf.example"

if command -v shellcheck >/dev/null 2>&1; then
    echo "[T01] Running shellcheck..."
    while IFS= read -r -d '' f; do
        shellcheck -S warning "$f"
    done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/lib" "$ROOT_DIR/tools" "$ROOT_DIR/tests" -type f \( -name '*.sh' -o -path "$ROOT_DIR/bin/*" \) -print0 | sort -z)
else
    echo "[T01] Note: shellcheck binary not installed in current host (skipped lint, bash -n passed on $shell_count files)."
fi

echo "PASS: T01 static validation ($shell_count shell files checked)."
