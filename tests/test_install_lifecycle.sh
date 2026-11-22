#!/usr/bin/env bash
set -euo pipefail

# T03, T04, T05, T06 — Dry-run, idempotency, backup/restore conflict, rollback, privilege guards.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AD_BIN="$ROOT_DIR/bin/armbiandesk"

export ARMBIANDESK_TEST_FIXTURE_ONLY=1

TMP_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TMP_FIXTURE"' EXIT

# Build isolated OS/user fixture (non-1000 UID 1234, home with space!)
mkdir -p "$TMP_FIXTURE/etc" "$TMP_FIXTURE/home/desk user" "$TMP_FIXTURE/usr/share/xsessions" "$TMP_FIXTURE/usr/share/applications" "$TMP_FIXTURE/usr/local/bin"
cat >"$TMP_FIXTURE/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
deskuser:x:1234:1234:Desk User:/home/desk user:/bin/bash
EOF

# Pre-existing file to verify backup & restore fidelity, plus user browser profile to ensure untouched
printf 'EXISTING_STOCK_PANEL_XML\n' >"$TMP_FIXTURE/home/desk user/.config_marker"
mkdir -p "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml"
printf 'PREEXISTING_PANEL_CONTENT\n' >"$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
chmod 0640 "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
mkdir -p "$TMP_FIXTURE/home/desk user/.config/armbiandesk/chromium/Default"
printf 'KEEP_MY_COOKIES\n' >"$TMP_FIXTURE/home/desk user/.config/armbiandesk/chromium/Default/Cookies"

snapshot_tree() {
    (cd "$TMP_FIXTURE" && find . -type f -o -type l | sort | xargs -r sha256sum 2>/dev/null || true)
}

echo "[T03] Testing install --dry-run does not mutate fixture..."
before_snap="$(snapshot_tree)"
"$AD_BIN" install --user deskuser --profile minimal --destdir "$TMP_FIXTURE" --dry-run >/dev/null
after_snap="$(snapshot_tree)"
[ "$before_snap" = "$after_snap" ] || { echo "FAIL: T03 dry-run mutated fixture!" >&2; exit 1; }
echo "PASS: T03 dry-run immutable."

echo "[T04] Testing idempotent double install and uninstall..."
out1="$("$AD_BIN" install --user deskuser --profile minimal --destdir "$TMP_FIXTURE" 2>&1)"
backup_id1="$(printf '%s\n' "$out1" | sed -n 's/.*Backup ID: //p' | tail -n 1)"
[ -n "$backup_id1" ] || { echo "FAIL: T04 missing backup ID" >&2; exit 1; }

snap_after_first="$(snapshot_tree | grep -v 'backups/' | grep -v 'installed-manifest.tsv')"
"$AD_BIN" install --user deskuser --profile minimal --destdir "$TMP_FIXTURE" >/dev/null 2>&1
snap_after_second="$(snapshot_tree | grep -v 'backups/' | grep -v 'installed-manifest.tsv')"
[ "$snap_after_first" = "$snap_after_second" ] || { echo "FAIL: T04 second install altered installed tree!" >&2; exit 1; }

# Check T06: autologin was NOT enabled by default
[ ! -e "$TMP_FIXTURE/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf" ] || { echo "FAIL: T06 autologin enabled unexpectedly" >&2; exit 1; }
# Check profile isolation: user browser cookies untouched and not in backup
[ -f "$TMP_FIXTURE/home/desk user/.config/armbiandesk/chromium/Default/Cookies" ] || { echo "FAIL: T04 deleted browser profile" >&2; exit 1; }
[ ! -e "$TMP_FIXTURE/var/lib/armbiandesk/backups/$backup_id1/files/home/desk user/.config/armbiandesk/chromium/Default/Cookies" ] || { echo "FAIL: T04 backed up browser profile" >&2; exit 1; }

# Check manifest permissions (0600)
manifest_mode="$(stat -c '%a' "$TMP_FIXTURE/var/lib/armbiandesk/installed-manifest.tsv")"
[ "$manifest_mode" = "600" ] || { echo "FAIL: T04 manifest mode expected 600, got $manifest_mode" >&2; exit 1; }

# Check restore --dry-run (T03) and conflict detection + restore (T05)
"$AD_BIN" restore --backup "$backup_id1" --destdir "$TMP_FIXTURE" --dry-run >/dev/null

# Simulate user editing xfce4-panel.xml after install -> conflict skip must preserve edit
printf 'USER_CUSTOM_EDIT\n' >"$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
restore_out="$("$AD_BIN" restore --backup "$backup_id1" --destdir "$TMP_FIXTURE" 2>&1)"
printf '%s\n' "$restore_out" | grep -q 'CONFLICT SKIP' || { echo "FAIL: T05 missing conflict skip notice" >&2; exit 1; }
grep -q 'USER_CUSTOM_EDIT' "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" || { echo "FAIL: T05 overwrote user edit without --force" >&2; exit 1; }

# Restore with --force -> restores exact original content & mode 0640
"$AD_BIN" restore --backup "$backup_id1" --destdir "$TMP_FIXTURE" --force >/dev/null 2>&1
grep -q 'PREEXISTING_PANEL_CONTENT' "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" || { echo "FAIL: T05 --force failed to restore original content" >&2; exit 1; }
restored_mode="$(stat -c '%a' "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml")"
[ "$restored_mode" = "640" ] || { echo "FAIL: T05 mode expected 640, got $restored_mode" >&2; exit 1; }

# Re-install and test uninstall twice + autologin opt-in
"$AD_BIN" install --user deskuser --profile desktop --enable-autologin --destdir "$TMP_FIXTURE" >/dev/null 2>&1
[ -f "$TMP_FIXTURE/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf" ] || { echo "FAIL: T06 --enable-autologin did not create drop-in" >&2; exit 1; }
"$AD_BIN" uninstall --user deskuser --destdir "$TMP_FIXTURE" --dry-run >/dev/null
"$AD_BIN" uninstall --user deskuser --destdir "$TMP_FIXTURE" >/dev/null 2>&1
"$AD_BIN" uninstall --user deskuser --destdir "$TMP_FIXTURE" >/dev/null 2>&1
[ ! -e "$TMP_FIXTURE/usr/local/bin/armbiandesk" ] || { echo "FAIL: T04 uninstall left binary" >&2; exit 1; }
[ -f "$TMP_FIXTURE/home/desk user/.config/armbiandesk/chromium/Default/Cookies" ] || { echo "FAIL: T04 uninstall touched browser cookies" >&2; exit 1; }

echo "[T05] Testing mid-install simulated failure & automatic rollback..."
printf 'BEFORE_FAIL_CONTENT\n' >"$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
set +e
ARMBIANDESK_FAIL_AFTER_STEP=16 "$AD_BIN" install --user deskuser --profile desktop --destdir "$TMP_FIXTURE" >/dev/null 2>&1
fail_rc=$?
set -e
[ "$fail_rc" -ne 0 ] || { echo "FAIL: T05 simulated failure exited 0" >&2; exit 1; }
grep -q 'BEFORE_FAIL_CONTENT' "$TMP_FIXTURE/home/desk user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" || { echo "FAIL: T05 rollback failed to restore pre-existing file" >&2; exit 1; }
[ ! -e "$TMP_FIXTURE/usr/local/bin/armbiandesk" ] || { echo "FAIL: T05 rollback left partial NEW file" >&2; exit 1; }

echo "[T05/T06] Testing missing user, root user rejection, and backup traversal rejection..."
! "$AD_BIN" install --user nonexistent --destdir "$TMP_FIXTURE" >/dev/null 2>&1 || { echo "FAIL: accepted missing user" >&2; exit 1; }
! "$AD_BIN" install --user root --destdir "$TMP_FIXTURE" >/dev/null 2>&1 || { echo "FAIL: accepted root user" >&2; exit 1; }
! "$AD_BIN" restore --backup "../../etc" --destdir "$TMP_FIXTURE" >/dev/null 2>&1 || { echo "FAIL: accepted path traversal backup ID" >&2; exit 1; }

echo "PASS: T03, T04, T05, T06 install/uninstall/restore/rollback/guards."
