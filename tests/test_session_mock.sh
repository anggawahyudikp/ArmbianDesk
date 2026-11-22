#!/usr/bin/env bash
set -euo pipefail

# T06 (runtime flags), T07, T08, T09, T10 — Mocked X11/WM/browser session lifecycle tests.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AD_BIN="$ROOT_DIR/bin/armbiandesk"

TMP_MOCK="$(mktemp -d)"
trap 'rm -rf "$TMP_MOCK"' EXIT

MOCK_BIN="$TMP_MOCK/bin"
MOCK_HOME="$TMP_MOCK/home"
MOCK_XDG_CFG="$MOCK_HOME/.config"
MOCK_RT="$TMP_MOCK/runtime"
MOCK_LOG="$TMP_MOCK/events.log"
mkdir -p "$MOCK_BIN" "$MOCK_HOME" "$MOCK_XDG_CFG/armbiandesk" "$MOCK_RT"
chmod 0700 "$MOCK_RT"

# Create mock X11/desktop/browser binaries
cat >"$MOCK_BIN/xset" <<'EOF'
#!/usr/bin/env bash
echo "xset $*" >>"$MOCK_LOG"
EOF
cat >"$MOCK_BIN/xrandr" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--query" ]; then
    printf 'HDMI-1 connected primary 1280x720+0+0\n   1280x720      60.00*+\n'
fi
echo "xrandr $*" >>"$MOCK_LOG"
EOF
cat >"$MOCK_BIN/feh" <<'EOF'
#!/usr/bin/env bash
echo "feh $*" >>"$MOCK_LOG"
EOF
cat >"$MOCK_BIN/xprop" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-root" ] && [ "${2:-}" = "_NET_SUPPORTING_WM_CHECK" ]; then
    echo "_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x100001"
fi
EOF
cat >"$MOCK_BIN/xdotool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$MOCK_BIN/wmctrl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$MOCK_BIN/xclock" <<'EOF'
#!/usr/bin/env bash
echo "xclock $*" >>"$MOCK_LOG"
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
cat >"$MOCK_BIN/openbox" <<'EOF'
#!/usr/bin/env bash
echo "openbox $*" >>"$MOCK_LOG"
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
cat >"$MOCK_BIN/xfwm4" <<'EOF'
#!/usr/bin/env bash
echo "xfwm4 $*" >>"$MOCK_LOG"
if [ "${MOCK_XFWM4_FAIL:-0}" = "1" ]; then
    exit 1
fi
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
cat >"$MOCK_BIN/xfce4-panel" <<'EOF'
#!/usr/bin/env bash
echo "xfce4-panel $*" >>"$MOCK_LOG"
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
cat >"$MOCK_BIN/plank" <<'EOF'
#!/usr/bin/env bash
echo "plank $*" >>"$MOCK_LOG"
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
cat >"$MOCK_BIN/gsettings" <<'EOF'
#!/usr/bin/env bash
echo "gsettings $*" >>"$MOCK_LOG"
EOF
cat >"$MOCK_BIN/chromium" <<'EOF'
#!/usr/bin/env bash
echo "chromium $*" >>"$MOCK_LOG"
if [ "${MOCK_BROWSER_CRASH:-0}" = "1" ]; then
    exit 1
fi
if [ "${MOCK_BROWSER_EXIT_OK:-0}" = "1" ]; then
    exit 0
fi
trap 'exit 0' TERM INT
while true; do sleep 0.2; done
EOF
chmod +x "$MOCK_BIN"/*

export PATH="$MOCK_BIN:$PATH"
export HOME="$MOCK_HOME"
export XDG_CONFIG_HOME="$MOCK_XDG_CFG"
export XDG_RUNTIME_DIR="$MOCK_RT"
export DISPLAY=":99"
export MOCK_LOG

# Spawn an unrelated user background process to prove session cleanup never kills it
sleep 30 &
UNRELATED_PID=$!
trap 'kill "$UNRELATED_PID" 2>/dev/null || true; rm -rf "$TMP_MOCK"' EXIT

echo "[T06/T09/T10] Testing browser launcher flags, normal exit, and bounded crash recovery..."
cat >"$MOCK_XDG_CFG/armbiandesk/armbiandesk.conf" <<'EOF'
PROFILE=minimal
START_URL=https://example.org/?q=1&b=2
BROWSER_AUTOSTART=true
BROWSER_BINARY=auto
BROWSER_COMPATIBILITY=standard
EOF

# Normal exit (0) must NOT trigger restart
MOCK_BROWSER_EXIT_OK=1 "$AD_BIN" browser --autostart
calls="$(grep -c '^chromium ' "$MOCK_LOG" || true)"
[ "$calls" -eq 1 ] || { echo "FAIL: T09 normal exit triggered reopen (calls=$calls)" >&2; exit 1; }

# Verify T06 sandbox & flag safety
! grep -q -- '--no-sandbox' "$MOCK_LOG" || { echo "FAIL: T06 --no-sandbox emitted!" >&2; exit 1; }
! grep -q -- '--remote-debugging-port' "$MOCK_LOG" || { echo "FAIL: T06 remote debug port emitted!" >&2; exit 1; }
grep -q -- '--class=ArmbianDeskBrowser' "$MOCK_LOG" || { echo "FAIL: T08 missing ArmbianDeskBrowser class" >&2; exit 1; }
[ "$(stat -c '%a' "$MOCK_XDG_CFG/armbiandesk/chromium")" = "700" ] || { echo "FAIL: T06 profile dir not 0700" >&2; exit 1; }

# Bounded crash recovery (max 2 retries -> 3 total launches, no infinite storm)
: >"$MOCK_LOG"
# Override sleep in mock to speed up exponential backoff check
cat >"$MOCK_BIN/sleep" <<'EOF'
#!/usr/bin/env bash
echo "sleep $*" >>"$MOCK_LOG"
EOF
chmod +x "$MOCK_BIN/sleep"

set +e
ARMBIANDESK_MAX_BROWSER_RESTARTS=2 MOCK_BROWSER_CRASH=1 "$AD_BIN" browser --autostart >/dev/null 2>&1
crash_rc=$?
set -e
rm -f "$MOCK_BIN/sleep"
[ "$crash_rc" -ne 0 ] || { echo "FAIL: T09 crash loop returned 0" >&2; exit 1; }
crash_calls="$(grep -c '^chromium ' "$MOCK_LOG" || true)"
[ "$crash_calls" -eq 3 ] || { echo "FAIL: T09 expected 3 total launches (1 + 2 retries), got $crash_calls" >&2; exit 1; }

echo "[T07] Testing minimal session startup and child cleanup on TERM..."
: >"$MOCK_LOG"
"$AD_BIN" session >/dev/null 2>&1 &
sess_pid=$!
sleep 1.2
kill -TERM "$sess_pid"
wait "$sess_pid" 2>/dev/null || true

grep -q '^openbox ' "$MOCK_LOG" || { echo "FAIL: T07 openbox did not start" >&2; exit 1; }
grep -q '^xclock ' "$MOCK_LOG" || { echo "FAIL: T07 xclock did not start" >&2; exit 1; }
grep -q '^feh ' "$MOCK_LOG" || { echo "FAIL: T07 wallpaper feh did not run" >&2; exit 1; }
kill -0 "$UNRELATED_PID" 2>/dev/null || { echo "FAIL: T07 cleanup killed unrelated user process!" >&2; exit 1; }

echo "[T08/T09] Testing desktop session + single plank + xfwm4 failure fallback to minimal..."
cat >"$MOCK_XDG_CFG/armbiandesk/armbiandesk.conf" <<'EOF'
PROFILE=desktop
START_URL=
BROWSER_AUTOSTART=false
DOCK_AUTOHIDE=true
DOCK_ZOOM=false
ENABLE_COMPOSITOR=false
STARTUP_SOUND=false
EOF

: >"$MOCK_LOG"
"$AD_BIN" session >/dev/null 2>&1 &
sess_pid=$!
sleep 1.2
kill -TERM "$sess_pid"
wait "$sess_pid" 2>/dev/null || true

grep -q '^xfwm4 --compositor=off' "$MOCK_LOG" || { echo "FAIL: T08 xfwm4 --compositor=off missing" >&2; exit 1; }
grep -q '^xfce4-panel ' "$MOCK_LOG" || { echo "FAIL: T08 xfce4-panel missing" >&2; exit 1; }
[ "$(grep -c '^plank' "$MOCK_LOG")" -eq 1 ] || { echo "FAIL: T08 expected single plank launch" >&2; exit 1; }
grep -q 'zoom-enabled false' "$MOCK_LOG" || { echo "FAIL: T08 dock zoom not disabled" >&2; exit 1; }

: >"$MOCK_LOG"
MOCK_XFWM4_FAIL=1 "$AD_BIN" session >/dev/null 2>&1 &
sess_pid=$!
sleep 1.2
kill -TERM "$sess_pid"
wait "$sess_pid" 2>/dev/null || true
grep -q '^openbox ' "$MOCK_LOG" || { echo "FAIL: T09 fallback to minimal openbox failed when xfwm4 crashed" >&2; exit 1; }

echo "[T12] Testing status --json and read-only benchmark collector..."
"$AD_BIN" status --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["product"]=="ArmbianDesk"'
"$AD_BIN" benchmark --duration 2 --interval 1 --output "$TMP_MOCK/bench" >/dev/null
[ -n "$(ls "$TMP_MOCK/bench"/benchmark-*.json)" ] || { echo "FAIL: benchmark JSON not created" >&2; exit 1; }

echo "PASS: T06(flags), T07, T08, T09, T10, T12(collector) all passed."
