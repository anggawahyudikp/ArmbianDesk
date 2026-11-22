#!/usr/bin/env bash
# Sandboxed browser launcher, WM_CLASS focus handler, and bounded autostart.

ad_detect_browser_binary() {
    local configured="${1:-auto}"
    if [ "$configured" != "auto" ]; then
        if [ -x "$configured" ]; then
            printf '%s\n' "$configured"
            return 0
        fi
        ad_err "Configured BROWSER_BINARY is not executable: $configured"
        return 1
    fi

    local cand resolved
    for cand in chromium chromium-browser google-chrome firefox-esr firefox; do
        if command -v "$cand" >/dev/null 2>&1; then
            resolved="$(command -v "$cand")"
            if head -n 5 "$resolved" 2>/dev/null | grep -q 'snap'; then
                ad_warn "Detected wrapper script ($resolved) referencing snap; native .deb Chromium is recommended."
            fi
            printf '%s\n' "$resolved"
            return 0
        fi
    done

    for cand in \
        /usr/bin/chromium \
        /usr/bin/chromium-browser \
        /usr/bin/google-chrome \
        /usr/bin/firefox-esr \
        /usr/bin/firefox; do
        if [ -x "$cand" ]; then
            if head -n 5 "$cand" 2>/dev/null | grep -q 'snap'; then
                ad_warn "Detected wrapper script ($cand) referencing snap; native .deb Chromium is recommended."
            fi
            printf '%s\n' "$cand"
            return 0
        fi
    done

    ad_err "No compatible browser binary found (install native chromium package)."
    return 1
}

ad_browser_runtime_dir() {
    local base="${XDG_RUNTIME_DIR:-/tmp}"
    local dir="$base/armbiandesk"
    mkdir -p "$dir"
    chmod 0700 "$dir" 2>/dev/null || true
    printf '%s\n' "$dir"
}

ad_find_browser_window() {
    local target_class="${1:-ArmbianDeskBrowser}"
    if command -v xdotool >/dev/null 2>&1; then
        xdotool search --class "$target_class" 2>/dev/null | head -n 1 || true
        return 0
    fi
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -lx 2>/dev/null | awk -v cls="$target_class" 'tolower($3) ~ tolower(cls) {print $1; exit}' || true
        return 0
    fi
}

ad_focus_browser_window() {
    local window_id="$1"
    [ -n "$window_id" ] || return 1
    if command -v xdotool >/dev/null 2>&1; then
        xdotool windowmap "$window_id" 2>/dev/null || true
        xdotool windowactivate "$window_id" 2>/dev/null || true
    fi
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -ir "$window_id" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    fi
}

ad_launch_browser() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        ad_die "Refusing to launch browser as root (UID 0). Run inside regular user session."
    fi

    [ -n "${DISPLAY:-}" ] || ad_die "DISPLAY is not set; graphical X11 session is required."

    ad_load_effective_config "" || return 1

    local url="${1:-$AD_CFG_START_URL}"
    if [ -n "$url" ]; then
        case "$url" in
            http://*|https://*) ;;
            -*) ad_die "Refusing URL starting with '-': $url" ;;
            *) ad_die "Unsupported URL scheme (only http:// or https:// allowed): $url" ;;
        esac
    fi

    local bin
    bin="$(ad_detect_browser_binary "$AD_CFG_BROWSER_BINARY")" || return 1

    # Focus existing ArmbianDesk browser window if no specific new URL requested
    local existing_win
    existing_win="$(ad_find_browser_window "ArmbianDeskBrowser")"
    if [ -n "$existing_win" ] && [ -z "${1:-}" ]; then
        ad_focus_browser_window "$existing_win"
        return 0
    fi

    local profile_dir="${XDG_CONFIG_HOME:-$HOME/.config}/armbiandesk/chromium"
    mkdir -p "$profile_dir"
    chmod 0700 "$profile_dir"

    local rt_dir
    rt_dir="$(ad_browser_runtime_dir)"
    local lock_file="$rt_dir/browser.lock"

    # Non-blocking single-launcher guard only when opening default startup
    if [ -z "${1:-}" ]; then
        exec 8>"$lock_file"
        if ! flock -n 8; then
            ad_log "Browser launcher already active for this session."
            return 0
        fi
    fi

    local -a flags=()
    local bin_base
    bin_base="$(basename "$bin")"

    case "$bin_base" in
        firefox*)
            flags+=(--profile "$profile_dir" --class=ArmbianDeskBrowser)
            ;;
        *)
            flags+=(
                --ozone-platform=x11
                "--user-data-dir=$profile_dir"
                --no-first-run
                --no-default-browser-check
                --disable-background-mode
                --start-maximized
                --class=ArmbianDeskBrowser
            )
            if [ "$AD_CFG_BROWSER_COMPATIBILITY" = "software-rendering" ]; then
                flags+=(--disable-gpu)
            fi
            ;;
    esac

    export LANG="${AD_CFG_LANGUAGE}"
    export GDK_BACKEND=x11

    local browser_pid
    if [ -n "$url" ]; then
        "$bin" "${flags[@]}" "$url" &
    else
        "$bin" "${flags[@]}" &
    fi
    browser_pid=$!

    # Forward TERM/INT cleanly so profile closes without crash state
    trap 'kill -TERM "$browser_pid" 2>/dev/null || true' TERM INT

    local attempt win_id
    for attempt in $(seq 1 30); do
        if ! kill -0 "$browser_pid" 2>/dev/null; then
            break
        fi
        win_id="$(ad_find_browser_window "ArmbianDeskBrowser")"
        if [ -n "$win_id" ]; then
            ad_focus_browser_window "$win_id"
            break
        fi
        sleep 0.5
    done

    wait "$browser_pid"
}

ad_browser_autostart() {
    ad_load_effective_config "" || return 1

    if [ "$AD_CFG_BROWSER_AUTOSTART" != "true" ]; then
        ad_log "BROWSER_AUTOSTART=false; skipping automatic browser launch."
        return 0
    fi
    if [ -z "$AD_CFG_START_URL" ]; then
        ad_log "START_URL is empty; skipping automatic browser launch."
        return 0
    fi

    # Bounded crash recovery: normal exit (0) never triggers reopen.
    local max_restarts="${ARMBIANDESK_MAX_BROWSER_RESTARTS:-3}"
    local crash_count=0
    local delay=5

    while true; do
        local started_at ended_at rc
        started_at="$(date +%s)"
        if ad_launch_browser "$AD_CFG_START_URL"; then
            rc=0
        else
            rc=$?
        fi
        ended_at="$(date +%s)"

        if [ "$rc" -eq 0 ] || [ "$rc" -eq 130 ] || [ "$rc" -eq 143 ]; then
            ad_log "Browser exited normally (code=$rc); not restarting."
            return 0
        fi

        # Reset crash counter if browser ran healthy for at least 120 seconds
        if [ $((ended_at - started_at)) -ge 120 ]; then
            crash_count=0
            delay=5
        fi

        crash_count=$((crash_count + 1))
        if [ "$crash_count" -gt "$max_restarts" ]; then
            ad_err "Browser crashed $crash_count times; stopping autostart retries to avoid respawn storm."
            return "$rc"
        fi

        ad_warn "Browser exited abnormally (code=$rc); retry $crash_count/$max_restarts in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
    done
}
