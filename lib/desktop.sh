#!/usr/bin/env bash
# Desktop helpers: Files launcher, confirmed power actions, and fixed icon visibility watcher.

ad_launch_files() {
    local target_dir="${1:-$HOME}"
    [ -n "${DISPLAY:-}" ] || ad_die "DISPLAY is not set."
    if [ ! -d "$target_dir" ]; then
        target_dir="$HOME"
    fi
    export GIO_USE_VFS=local

    if command -v thunar >/dev/null 2>&1; then
        exec thunar "$target_dir"
    elif command -v pcmanfm >/dev/null 2>&1; then
        exec pcmanfm "$target_dir"
    elif command -v xdg-open >/dev/null 2>&1; then
        exec xdg-open "$target_dir"
    else
        ad_die "No supported file manager found (install thunar or pcmanfm)."
    fi
}

ad_power_action() {
    local action="${1:-}"
    case "$action" in
        logout|reboot|shutdown) ;;
        *) ad_die "Usage: armbiandesk power <logout|reboot|shutdown>" ;;
    esac

    if [ -n "${DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
        zenity --question --title="ArmbianDesk" --text="Proceed with $action?" || return 0
    elif [ -n "${DISPLAY:-}" ] && command -v xmessage >/dev/null 2>&1; then
        xmessage -center -buttons "Cancel:1,Confirm:0" "ArmbianDesk: Confirm $action?" || return 0
    fi

    case "$action" in
        logout)
            if command -v openbox >/dev/null 2>&1 && pgrep -u "$(id -u)" -x openbox >/dev/null 2>&1; then
                openbox --exit
            elif [ -n "${ARMBIANDESK_SESSION_PID:-}" ]; then
                kill -TERM "$ARMBIANDESK_SESSION_PID" 2>/dev/null || true
            fi
            ;;
        reboot)
            systemctl reboot 2>/dev/null || loginctl reboot
            ;;
        shutdown)
            systemctl poweroff 2>/dev/null || loginctl poweroff
            ;;
    esac
}

# Fixed icon visibility helper: ignores desktop/dock/clock/minimized windows and uses XDG_RUNTIME_DIR lock.
ad_icon_visibility_watcher() {
    [ -n "${DISPLAY:-}" ] || ad_die "DISPLAY is not set."
    command -v wmctrl >/dev/null 2>&1 || return 0
    command -v xprop >/dev/null 2>&1 || return 0
    command -v idesk >/dev/null 2>&1 || return 0

    local rt_dir="${XDG_RUNTIME_DIR:-/tmp}/armbiandesk"
    mkdir -p "$rt_dir"
    chmod 0700 "$rt_dir" 2>/dev/null || true
    local lock_file="$rt_dir/icon-watcher.lock"
    local idesk_pid_file="$rt_dir/idesk.pid"

    exec 9>"$lock_file"
    flock -n 9 || return 0

    idesk_is_alive() {
        [ -f "$idesk_pid_file" ] || return 1
        local pid
        pid="$(cat "$idesk_pid_file" 2>/dev/null || true)"
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
    }

    stop_owned_idesk() {
        if idesk_is_alive; then
            local pid
            pid="$(cat "$idesk_pid_file")"
            kill -TERM "$pid" 2>/dev/null || true
            rm -f "$idesk_pid_file"
        fi
    }

    has_visible_normal_window() {
        local window_id _ wclass wstate wtype
        while read -r window_id _; do
            [ -n "${window_id:-}" ] || continue
            # Skip sticky desktop/panel windows (-1) unless normal
            wclass="$(xprop -id "$window_id" WM_CLASS 2>/dev/null || true)"
            case "$wclass" in
                *ArmbianDeskClock*|*xfce4-panel*|*Plank*|*plank*|*Idesk*|*idesk*) continue ;;
            esac
            wtype="$(xprop -id "$window_id" _NET_WM_WINDOW_TYPE 2>/dev/null || true)"
            case "$wtype" in
                *_NET_WM_WINDOW_TYPE_DESKTOP*|*_NET_WM_WINDOW_TYPE_DOCK*) continue ;;
            esac
            wstate="$(xprop -id "$window_id" _NET_WM_STATE 2>/dev/null || true)"
            case "$wstate" in
                *_NET_WM_STATE_HIDDEN*|*_NET_WM_STATE_SKIP_TASKBAR*) continue ;;
            esac
            return 0
        done < <(wmctrl -l 2>/dev/null)
        return 1
    }

    sync_icons() {
        if has_visible_normal_window; then
            stop_owned_idesk
        elif ! idesk_is_alive; then
            idesk >"$rt_dir/idesk.log" 2>&1 &
            printf '%s\n' "$!" >"$idesk_pid_file"
        fi
    }

    trap 'stop_owned_idesk' EXIT TERM INT
    sync_icons

    xprop -root -spy _NET_CLIENT_LIST _NET_CLIENT_LIST_STACKING _NET_ACTIVE_WINDOW 2>/dev/null |
    while IFS= read -r _; do
        sync_icons
    done
}
