#!/usr/bin/env bash
# Shared utilities, path safety, and user resolution for ArmbianDesk.

ARMBIANDESK_VERSION="0.1.0"

ad_log() {
    printf '[armbiandesk] %s\n' "$*" >&2
}

ad_warn() {
    printf '[armbiandesk][WARN] %s\n' "$*" >&2
}

ad_err() {
    printf '[armbiandesk][ERROR] %s\n' "$*" >&2
}

ad_die() {
    ad_err "$*"
    exit 1
}

# Resolve repository / installed share root cleanly.
ad_find_share_dir() {
    local self_dir
    self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -d "$self_dir/share" ] && [ -d "$self_dir/config" ]; then
        printf '%s\n' "$self_dir"
        return 0
    fi
    if [ -d "/usr/local/share/armbiandesk" ]; then
        printf '%s\n' "/usr/local/share/armbiandesk"
        return 0
    fi
    if [ -d "/usr/share/armbiandesk" ]; then
        printf '%s\n' "/usr/share/armbiandesk"
        return 0
    fi
    return 1
}

# Normalize DESTDIR (empty for live system, or absolute path without trailing slash).
ad_normalize_destdir() {
    local raw="${1:-}"
    if [ -z "$raw" ] || [ "$raw" = "/" ]; then
        printf ''
        return 0
    fi
    python3 -c '
import os, sys
p = os.path.abspath(sys.argv[1])
if p == "/":
    print("")
else:
    print(p.rstrip("/"))
' "$raw"
}

# Reject live root target when test fixture isolation is enforced.
ad_guard_fixture_only() {
    local destdir="$1"
    if [ "${ARMBIANDESK_TEST_FIXTURE_ONLY:-0}" = "1" ] && [ -z "$destdir" ]; then
        ad_die "Refusing to write to live '/' while ARMBIANDESK_TEST_FIXTURE_ONLY=1"
    fi
}

# Validate a safe identifier (backup IDs, profile names, usernames).
ad_validate_ident() {
    local val="$1"
    local label="${2:-identifier}"
    case "$val" in
        ""|*/*|*..*) ad_die "Invalid $label: $val" ;;
    esac
    if ! printf '%s' "$val" | grep -Eq '^[A-Za-z0-9._-]+$'; then
        ad_die "Invalid $label format: $val"
    fi
}

# Resolve target user record: "uid:gid:home" from DESTDIR/etc/passwd first, then getent.
ad_resolve_user() {
    local user="$1"
    local destdir="${2:-}"
    ad_validate_ident "$user" "username"

    python3 -c '
import os, pwd, sys

user, destdir = sys.argv[1], sys.argv[2]
record = None

if destdir:
    passwd_file = os.path.join(destdir, "etc", "passwd")
    if os.path.isfile(passwd_file) and not os.path.islink(passwd_file):
        with open(passwd_file, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                parts = line.rstrip("\n").split(":")
                if len(parts) >= 6 and parts[0] == user:
                    record = (int(parts[2]), int(parts[3]), parts[5])
                    break

if record is None and not destdir:
    try:
        pw = pwd.getpwnam(user)
        record = (pw.pw_uid, pw.pw_gid, pw.pw_dir)
    except KeyError:
        pass
elif record is None and destdir:
    # Allow fallback to host getent ONLY if not strictly isolated? No, reject missing user in fixture!
    pass

if record is None:
    sys.stderr.write(f"User not found: {user}\n")
    sys.exit(1)

uid, gid, home = record
if uid == 0:
    sys.stderr.write("Refusing root (UID 0) as target desktop user\n")
    sys.exit(1)
if not home.startswith("/") or ".." in home.split("/"):
    sys.stderr.write(f"Invalid home path for {user}: {home}\n")
    sys.exit(1)

print(f"{uid}\t{gid}\t{home}")
' "$user" "$destdir"
}

# Check target path inside destdir is not a symlink escape.
ad_assert_safe_target() {
    local destdir="$1"
    local rel_path="$2"
    python3 -c '
import os, sys

destdir, rel_path = sys.argv[1], sys.argv[2]
if not rel_path.startswith("/"):
    sys.exit(1)
parts = [p for p in rel_path.split("/") if p]
if ".." in parts:
    sys.stderr.write(f"Path traversal rejected: {rel_path}\n")
    sys.exit(1)

base = destdir if destdir else "/"
cur = os.path.abspath(base)
for part in parts:
    cur = os.path.join(cur, part)
    if os.path.islink(cur):
        sys.stderr.write(f"Symlink target rejected: {cur}\n")
        sys.exit(1)
' "$destdir" "$rel_path"
}

# Write stdin atomically to target file with mode (octal) and optional uid:gid.
ad_atomic_write() {
    local target="$1"
    local mode="${2:-0644}"
    local owner="${3:-}"
    local parent
    parent="$(dirname "$target")"
    mkdir -p "$parent"
    local tmp
    tmp="$(mktemp "$parent/.armbiandesk.tmp.XXXXXX")" || return 1
    cat >"$tmp" || { rm -f "$tmp"; return 1; }
    chmod "$mode" "$tmp" || { rm -f "$tmp"; return 1; }
    if [ -n "$owner" ] && [ "${EUID:-$(id -u)}" -eq 0 ]; then
        chown "$owner" "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    mv -f "$tmp" "$target"
}
