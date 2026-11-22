#!/usr/bin/env bash
# X11 desktop session manager for ArmbianDesk (minimal and desktop profiles).

AD_SESSION_CHILD_PIDS=()
AD_SESSION_CLEANED=0

ad_session_cleanup() {
    if [ "$AD_SESSION_CLEANED" -eq 1 ]; then
        return 0
    fi
    AD_SESSION_CLEANED=1

    local pid
    for pid in "${AD_SESSION_CHILD_PIDS[@]:-}"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done

    local wait_i=0
    while [ "$wait_i" -lt 20 ]; do
        local any_alive=0
        for pid in "${AD_SESSION_CHILD_PIDS[@]:-}"; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                any_alive=1
                break
            fi
        done
        [ "$any_alive" -eq 0 ] && break
        sleep 0.1
        wait_i=$((wait_i + 1))
    done

    for pid in "${AD_SESSION_CHILD_PIDS[@]:-}"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done

    if [ -n "${AD_SESSION_RUN_DIR:-}" ] && [ -d "${AD_SESSION_RUN_DIR:-}" ]; then
        rm -rf "$AD_SESSION_RUN_DIR"
    fi
}

ad_wait_wm_ready() {
    local wm_pid="$1"
    local timeout_steps="${2:-50}" # 50 * 0.2s = 10s
    local i=0
    while [ "$i" -lt "$timeout_steps" ]; do
        if ! kill -0 "$wm_pid" 2>/dev/null; then
            return 1
        fi
        if [ "$i" -ge 2 ]; then
            if command -v xprop >/dev/null 2>&1; then
                if xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id # 0x'; then
                    return 0
                fi
            else
                return 0
            fi
        fi
        sleep 0.2
        i=$((i + 1))
    done
    kill -0 "$wm_pid" 2>/dev/null
}

ad_apply_display_settings() {
    if [ "$AD_CFG_KEEP_AWAKE" = "true" ] && command -v xset >/dev/null 2>&1; then
        xset s off 2>/dev/null || true
        xset s noblank 2>/dev/null || true
        xset -dpms 2>/dev/null || true
        xset dpms 0 0 0 2>/dev/null || true
    fi

    if command -v xrandr >/dev/null 2>&1; then
        local xr_out output
        xr_out="$(xrandr --query 2>/dev/null || true)"
        output="$(printf '%s\n' "$xr_out" | awk '/ connected/{print $1; exit}')"
        if [ -n "${output:-}" ]; then
            if [ "$AD_CFG_DISPLAY_MODE" = "auto" ]; then
                xrandr --output "$output" --auto --primary 2>/dev/null || \
                    xrandr --output "$output" --primary 2>/dev/null || true
            else
                local mode="${AD_CFG_DISPLAY_MODE%@*}"
                if printf '%s\n' "$xr_out" | grep -qF "$mode"; then
                    xrandr --output "$output" --mode "$mode" --primary 2>/dev/null || true
                else
                    ad_warn "Requested DISPLAY_MODE '$AD_CFG_DISPLAY_MODE' not advertised by $output; using preferred auto mode."
                    xrandr --output "$output" --auto --primary 2>/dev/null || true
                fi
            fi
        fi
    fi
}

ad_apply_wallpaper() {
    local share_dir="$1"
    local wp="$share_dir/share/wallpapers/armbiandesk.svg"
    if [ ! -f "$wp" ] && [ -f "/usr/local/share/armbiandesk/wallpapers/armbiandesk.svg" ]; then
        wp="/usr/local/share/armbiandesk/wallpapers/armbiandesk.svg"
    fi

    if command -v feh >/dev/null 2>&1 && [ -f "$wp" ]; then
        feh --no-fehbg --bg-fill "$wp" 2>/dev/null && return 0
    fi
    if command -v xsetroot >/dev/null 2>&1; then
        xsetroot -solid '#111827' 2>/dev/null || true
    fi
}

ad_run_minimal_profile() {
    local share_dir="$1"
    local ob_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/armbiandesk/openbox/rc.xml"
    if [ ! -f "$ob_cfg" ]; then
        ob_cfg="$share_dir/share/openbox/rc.xml"
    fi

    command -v openbox >/dev/null 2>&1 || ad_die "openbox is required for minimal profile."

    openbox --config-file "$ob_cfg" &
    local wm_pid=$!
    AD_SESSION_CHILD_PIDS+=("$wm_pid")

    if ! ad_wait_wm_ready "$wm_pid" 50; then
        ad_die "openbox exited or failed to become ready."
    fi

    if command -v xclock >/dev/null 2>&1; then
        xclock -name ArmbianDeskClock -digital -update 60 \
            -strftime '%a, %d %b   %H:%M' \
            -face 'DejaVu Sans:style=Bold:size=12' \
            -fg '#E2E8F0' -bg '#1E293B' -borderwidth 0 \
            -geometry 230x42-18+18 >/dev/null 2>&1 &
        AD_SESSION_CHILD_PIDS+=("$!")
    fi

    if command -v idesk >/dev/null 2>&1; then
        "$ARMBIANDESK_BIN" internal-icon-watcher &
        AD_SESSION_CHILD_PIDS+=("$!")
    fi

    if [ "$AD_CFG_BROWSER_AUTOSTART" = "true" ] && [ -n "$AD_CFG_START_URL" ]; then
        "$ARMBIANDESK_BIN" browser --autostart &
        AD_SESSION_CHILD_PIDS+=("$!")
    fi

    wait "$wm_pid"
}

ad_configure_plank_gsettings() {
    command -v gsettings >/dev/null 2>&1 || return 0
    local hide_mode="intelligent"
    [ "$AD_CFG_DOCK_AUTOHIDE" = "false" ] && hide_mode="none"
    local zoom_enabled="false"
    [ "$AD_CFG_DOCK_ZOOM" = "true" ] && zoom_enabled="true"

    gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ alignment 'center' 2>/dev/null || true
    gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ hide-mode "$hide_mode" 2>/dev/null || true
    gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ zoom-enabled "$zoom_enabled" 2>/dev/null || true
    gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme 'ArmbianDesk' 2>/dev/null || true
    gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ position 'bottom' 2>/dev/null || true
}

ad_run_desktop_profile() {
    local share_dir="$1"

    if ! command -v xfwm4 >/dev/null 2>&1; then
        ad_warn "xfwm4 not installed; falling back to minimal profile."
        ad_run_minimal_profile "$share_dir"
        return $?
    fi

    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_DESKTOP=xfce

    local comp_flag="--compositor=off"
    if [ "$AD_CFG_ENABLE_COMPOSITOR" = "true" ]; then
        comp_flag="--compositor=on"
    fi

    xfwm4 "$comp_flag" --vblank=off &
    local wm_pid=$!
    AD_SESSION_CHILD_PIDS+=("$wm_pid")

    if ! ad_wait_wm_ready "$wm_pid" 50; then
        ad_warn "xfwm4 failed to become ready; cleaning up and falling back to minimal profile."
        kill -TERM "$wm_pid" 2>/dev/null || true
        wait "$wm_pid" 2>/dev/null || true
        AD_SESSION_CHILD_PIDS=()
        ad_run_minimal_profile "$share_dir"
        return $?
    fi

    # Start at most one xfce4-panel for this session
    if command -v xfce4-panel >/dev/null 2>&1; then
        xfce4-panel --disable-wm-check >/dev/null 2>&1 &
        AD_SESSION_CHILD_PIDS+=("$!")
    fi

    # Start at most one Plank dock owned by this session
    if command -v plank >/dev/null 2>&1; then
        local dock_lock="$AD_SESSION_RUN_DIR/plank.lock"
        if ( set -o noclobber; : > "$dock_lock" ) 2>/dev/null; then
            ad_configure_plank_gsettings
            plank >/dev/null 2>&1 &
            AD_SESSION_CHILD_PIDS+=("$!")
        fi
    fi

    if [ "$AD_CFG_BROWSER_AUTOSTART" = "true" ] && [ -n "$AD_CFG_START_URL" ]; then
        "$ARMBIANDESK_BIN" browser --autostart &
        AD_SESSION_CHILD_PIDS+=("$!")
    fi

    wait "$wm_pid"
}

ad_start_session() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        ad_die "Refusing to start X11 desktop session as root (UID 0)."
    fi
    [ -n "${DISPLAY:-}" ] || ad_die "DISPLAY environment variable is missing; cannot start X11 session."

    ad_load_effective_config "" || return 1

    local share_dir
    share_dir="$(ad_find_share_dir)" || ad_die "Cannot locate ArmbianDesk share directory."

    export LANG="${AD_CFG_LANGUAGE}"
    export GDK_BACKEND=x11
    export NO_AT_BRIDGE=1
    export GTK_A11Y=none
    export GIO_USE_VFS=local
    unset GTK_MODULES
    unset LC_ALL

    AD_SESSION_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/armbiandesk/session.$$"
    mkdir -p "$AD_SESSION_RUN_DIR"
    chmod 0700 "$AD_SESSION_RUN_DIR" 2>/dev/null || true
    export ARMBIANDESK_SESSION_PID="$$"

    trap ad_session_cleanup EXIT TERM INT

    ad_apply_display_settings
    ad_apply_wallpaper "$share_dir"

    case "$AD_CFG_PROFILE" in
        minimal)
            ad_run_minimal_profile "$share_dir"
            ;;
        desktop)
            ad_run_desktop_profile "$share_dir"
            ;;
        *)
            ad_die "Invalid configured profile: $AD_CFG_PROFILE"
            ;;
    esac
}
