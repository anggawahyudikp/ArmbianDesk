#!/usr/bin/env bash
set -euo pipefail

# Privacy, secrets, symlink, and line-ending sanity scanner (T13).
# Optional private deny-pattern file may be passed via ARMBIANDESK_PRIVATE_DENYLIST (kept outside public repo).

TARGET_DIR="${1:-.}"
DENYLIST_FILE="${ARMBIANDESK_PRIVATE_DENYLIST:-}"

python3 - "$TARGET_DIR" "$DENYLIST_FILE" <<'PY'
import os, re, sys

root = os.path.abspath(sys.argv[1])
denylist_path = sys.argv[2]

secret_patterns = [
    ("private_key_header", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("github_token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b")),
]

code_patterns = [
    ("hardcoded_uid1000_home", re.compile(r"/run/user/1000\b")),
    ("hardcoded_display0", re.compile(r"\bDISPLAY=:0\b")),
    ("chromium_no_sandbox", re.compile(r"--no-sandbox\b")),
]

extra_patterns = []
if denylist_path and os.path.isfile(denylist_path):
    with open(denylist_path, "r", encoding="utf-8") as fh:
        for idx, line in enumerate(fh, start=1):
            pat = line.strip()
            if pat and not pat.startswith("#"):
                extra_patterns.append((f"private_deny_{idx}", re.compile(re.escape(pat), re.IGNORECASE)))

issues = []
checked_files = 0
code_prefixes = ("bin/", "lib/", "config/", "share/", "tools/")

for dirpath, dirnames, filenames in os.walk(root):
    for skip_dir in (".git", "dist", "__pycache__"):
        if skip_dir in dirnames:
            dirnames.remove(skip_dir)
    for name in filenames + dirnames:
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, root)
        if os.path.islink(full):
            issues.append(f"SYMLINK: {rel}")

    for fname in filenames:
        full = os.path.join(dirpath, fname)
        rel = os.path.relpath(full, root).replace(os.sep, "/")
        if os.path.islink(full):
            continue
        if rel in ("tools/sanitize-check.sh", "tests/test_release_sanitize.sh"):
            continue
        checked_files += 1
        try:
            raw = open(full, "rb").read()
        except OSError as exc:
            issues.append(f"READ_ERROR: {rel}: {exc}")
            continue
        if b"\0" in raw:
            if fname.lower().endswith((".bin", ".key", ".pem", ".sqlite", ".db")):
                issues.append(f"FORBIDDEN_BINARY: {rel}")
            continue
        if b"\r\n" in raw:
            issues.append(f"CRLF_LINE_ENDINGS: {rel}")
        text = raw.decode("utf-8", errors="replace")
        active_patterns = list(secret_patterns) + list(extra_patterns)
        if rel.startswith(code_prefixes):
            active_patterns.extend(code_patterns)
        for label, pat in active_patterns:
            if pat.search(text):
                issues.append(f"FORBIDDEN_PATTERN({label}): {rel}")

print(f"Sanitize scan checked {checked_files} files in {root}")
if issues:
    for item in issues:
        print("FAIL:", item)
    sys.exit(1)
print("Sanitize scan PASSED: 0 issues.")
PY
