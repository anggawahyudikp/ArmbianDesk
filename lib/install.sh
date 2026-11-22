#!/usr/bin/env bash
# Idempotent installer, uninstaller, atomic backup, and conflict-aware restore.

ad_install_usage() {
    cat <<'EOF'
Usage:
  armbiandesk install --user USER [--profile minimal|desktop] [--destdir DIR|--root DIR] [--enable-autologin] [--dry-run]
  armbiandesk uninstall --user USER [--destdir DIR|--root DIR] [--dry-run]
  armbiandesk restore --backup ID [--destdir DIR|--root DIR] [--force] [--dry-run]
  armbiandesk profile set <minimal|desktop> [--destdir DIR|--root DIR]
EOF
}

ad_backup_file_into_manifest() {
    local destdir="$1"
    local rel_path="$2"
    local backup_dir="$3"
    local manifest="$4"
    local abs_target="${destdir}${rel_path}"

    ad_assert_safe_target "$destdir" "$rel_path"

    if [ -e "$abs_target" ]; then
        local dst_backup="$backup_dir/files${rel_path}"
        mkdir -p "$(dirname "$dst_backup")"
        cp -p "$abs_target" "$dst_backup"
        local sha mode uid gid
        sha="$(sha256sum "$abs_target" | awk '{print $1}')"
        mode="$(stat -c '%a' "$abs_target")"
        uid="$(stat -c '%u' "$abs_target")"
        gid="$(stat -c '%g' "$abs_target")"
        printf 'EXIST\t%s\t%s\t%s\t%s\t%s\tPENDING\n' "$rel_path" "$sha" "$mode" "$uid" "$gid" >>"$manifest"
    else
        printf 'NEW\t%s\t-\t-\t-\t-\tPENDING\n' "$rel_path" >>"$manifest"
    fi
}

ad_record_installed_sha() {
    local destdir="$1"
    local rel_path="$2"
    local manifest="$3"
    local abs_target="${destdir}${rel_path}"
    local new_sha
    new_sha="$(sha256sum "$abs_target" | awk '{print $1}')"

    python3 - "$manifest" "$rel_path" "$new_sha" <<'PY'
import sys
manifest, rel_path, new_sha = sys.argv[1:4]
lines = []
with open(manifest, "r", encoding="utf-8") as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) == 7 and parts[1] == rel_path:
            parts[6] = new_sha
            lines.append("\t".join(parts) + "\n")
        else:
            lines.append(line)
with open(manifest, "w", encoding="utf-8") as fh:
    fh.writelines(lines)
PY
}

ad_rollback_manifest_partial() {
    local destdir="$1"
    local backup_dir="$2"
    local manifest="$3"
    [ -f "$manifest" ] || return 0

    ad_warn "Rolling back partially installed files from $manifest..."
    # Reverse order rollback
    tac "$manifest" | while IFS=$'\t' read -r kind rel_path orig_sha orig_mode orig_uid orig_gid inst_sha; do
        [ -n "$rel_path" ] || continue
        local abs_target="${destdir}${rel_path}"
        if [ "$kind" = "NEW" ]; then
            rm -f "$abs_target"
        elif [ "$kind" = "EXIST" ] && [ -f "$backup_dir/files${rel_path}" ]; then
            mkdir -p "$(dirname "$abs_target")"
            cp -p "$backup_dir/files${rel_path}" "$abs_target"
            chmod "$orig_mode" "$abs_target" 2>/dev/null || true
            if [ "${EUID:-$(id -u)}" -eq 0 ]; then
                chown "${orig_uid}:${orig_gid}" "$abs_target" 2>/dev/null || true
            fi
        fi
    done
}

ad_cmd_install() {
    local target_user="" profile="minimal" destdir="" enable_autologin=0 dry_run=0 config_override=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --user) target_user="${2:-}"; shift 2 ;;
            --profile) profile="${2:-}"; shift 2 ;;
            --destdir|--root) destdir="${2:-}"; shift 2 ;;
            --config) config_override="${2:-}"; shift 2 ;;
            --enable-autologin) enable_autologin=1; shift ;;
            --dry-run) dry_run=1; shift ;;
            -h|--help) ad_install_usage; return 0 ;;
            *) ad_die "Unknown install option: $1" ;;
        esac
    done

    [ -n "$target_user" ] || ad_die "--user USER is required"
    case "$profile" in
        minimal|desktop) ;;
        *) ad_die "Invalid profile '$profile' (must be minimal or desktop)" ;;
    esac

    destdir="$(ad_normalize_destdir "$destdir")"
    ad_guard_fixture_only "$destdir"

    local user_rec uid gid home_dir
    user_rec="$(ad_resolve_user "$target_user" "$destdir")" || return 1
    IFS=$'\t' read -r uid gid home_dir <<< "$user_rec"

    local share_dir
    share_dir="$(ad_find_share_dir)" || ad_die "Cannot locate ArmbianDesk source files."

    # Check storage headroom (at least 10 MiB free on destination filesystem)
    local check_dir="${destdir:-/}"
    mkdir -p "$check_dir"
    local avail_kb
    avail_kb="$(df -Pk "$check_dir" | awk 'NR==2{print $4}')"
    if [ -n "$avail_kb" ] && [ "$avail_kb" -lt 10240 ]; then
        ad_die "Insufficient disk space in '$check_dir' (${avail_kb} KiB available, need >= 10240 KiB)."
    fi

    # Validate any provided config file before modifying anything
    local src_conf="$share_dir/config/armbiandesk.conf.example"
    if [ -n "$config_override" ]; then
        ad_parse_config "$config_override" || return 1
        src_conf="$config_override"
    fi

    local rel_targets=(
        "/usr/local/bin/armbiandesk"
        "/usr/local/share/armbiandesk/wallpapers/armbiandesk.svg"
        "/usr/local/share/armbiandesk/openbox/rc.xml"
        "/usr/local/share/armbiandesk/openbox/menu.xml"
        "/usr/local/share/armbiandesk/xfce4/xfce4-panel.xml"
        "/usr/local/share/armbiandesk/xfce4/xfwm4.xml"
        "/usr/local/share/armbiandesk/plank/dock.theme"
        "/usr/local/share/armbiandesk/lib/common.sh"
        "/usr/local/share/armbiandesk/lib/config.sh"
        "/usr/local/share/armbiandesk/lib/browser.sh"
        "/usr/local/share/armbiandesk/lib/desktop.sh"
        "/usr/local/share/armbiandesk/lib/session.sh"
        "/usr/local/share/armbiandesk/lib/install.sh"
        "/usr/local/share/armbiandesk/lib/status.sh"
        "/etc/armbiandesk/armbiandesk.conf"
        "/usr/share/xsessions/armbiandesk.desktop"
        "/usr/share/applications/armbiandesk-browser.desktop"
        "/usr/share/applications/armbiandesk-files.desktop"
        "${home_dir}/.config/armbiandesk/openbox/rc.xml"
        "${home_dir}/.config/armbiandesk/openbox/menu.xml"
        "${home_dir}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
        "${home_dir}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
        "${home_dir}/.local/share/plank/themes/ArmbianDesk/dock.theme"
        "${home_dir}/.config/plank/dock1/launchers/armbiandesk-browser.dockitem"
        "${home_dir}/.config/plank/dock1/launchers/armbiandesk-files.dockitem"
    )
    if [ "$enable_autologin" -eq 1 ]; then
        rel_targets+=("/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf")
    fi

    echo "=== ArmbianDesk Install Plan ==="
    echo "Target user   : $target_user (uid=$uid, gid=$gid, home=$home_dir)"
    echo "Profile       : $profile"
    echo "Destination   : ${destdir:-/}"
    echo "Autologin     : $([ "$enable_autologin" -eq 1 ] && echo enabled || echo disabled)"
    echo "Target paths  :"
    local t
    for t in "${rel_targets[@]}"; do
        echo "  - ${destdir}${t}"
    done

    if [ "$dry_run" -eq 1 ]; then
        echo "[dry-run] No files written, no packages installed, no services restarted."
        return 0
    fi

    local state_dir="${destdir}/var/lib/armbiandesk"
    local active_manifest="$state_dir/installed-manifest.tsv"
    local backup_id
    backup_id="install-$(date +%Y%m%d-%H%M%S)-$$"
    local backup_dir="$state_dir/backups/$backup_id"
    local run_manifest="$backup_dir/manifest.tsv"

    mkdir -p "$backup_dir/files"
    chmod 0700 "$state_dir" "$state_dir/backups" "$backup_dir"
    : > "$run_manifest"
    chmod 0600 "$run_manifest"

    # Perform atomic writes with automatic rollback on any failure
    install_step() {
        local step_num="$1" rel_path="$2" src_path="$3" mode="$4" owner="$5"
        if [ "${ARMBIANDESK_FAIL_AFTER_STEP:-0}" = "$step_num" ]; then
            ad_err "Simulated failure triggered at step $step_num"
            return 1
        fi
        ad_backup_file_into_manifest "$destdir" "$rel_path" "$backup_dir" "$run_manifest" || return 1
        ad_atomic_write "${destdir}${rel_path}" "$mode" "$owner" <"$src_path" || return 1
        ad_record_installed_sha "$destdir" "$rel_path" "$run_manifest" || return 1
    }

    local ok=1
    install_step 1  "/usr/local/bin/armbiandesk" "$share_dir/bin/armbiandesk" "0755" "" || ok=0
    install_step 2  "/usr/local/share/armbiandesk/wallpapers/armbiandesk.svg" "$share_dir/share/wallpapers/armbiandesk.svg" "0644" "" || ok=0
    install_step 3  "/usr/local/share/armbiandesk/openbox/rc.xml" "$share_dir/share/openbox/rc.xml" "0644" "" || ok=0
    install_step 4  "/usr/local/share/armbiandesk/openbox/menu.xml" "$share_dir/share/openbox/menu.xml" "0644" "" || ok=0
    install_step 5  "/usr/local/share/armbiandesk/xfce4/xfce4-panel.xml" "$share_dir/share/xfce4/xfce4-panel.xml" "0644" "" || ok=0
    install_step 6  "/usr/local/share/armbiandesk/xfce4/xfwm4.xml" "$share_dir/share/xfce4/xfwm4.xml" "0644" "" || ok=0
    install_step 7  "/usr/local/share/armbiandesk/plank/dock.theme" "$share_dir/share/plank/dock.theme" "0644" "" || ok=0

    if [ "$ok" -eq 1 ]; then
        local libfile
        for libfile in common.sh config.sh browser.sh desktop.sh session.sh install.sh status.sh; do
            install_step 8 "/usr/local/share/armbiandesk/lib/$libfile" "$share_dir/lib/$libfile" "0644" "" || { ok=0; break; }
        done
    fi

    if [ "$ok" -eq 1 ]; then
        # Render /etc/armbiandesk/armbiandesk.conf with selected PROFILE
        local tmp_cfg
        tmp_cfg="$(mktemp)"
        sed "s|^PROFILE=.*|PROFILE=${profile}|" "$src_conf" >"$tmp_cfg"
        install_step 9 "/etc/armbiandesk/armbiandesk.conf" "$tmp_cfg" "0644" "" || ok=0
        rm -f "$tmp_cfg"
    fi

    if [ "$ok" -eq 1 ]; then
        install_step 10 "/usr/share/xsessions/armbiandesk.desktop" "$share_dir/share/xsessions/armbiandesk.desktop" "0644" "" || ok=0
        install_step 11 "/usr/share/applications/armbiandesk-browser.desktop" "$share_dir/share/applications/armbiandesk-browser.desktop" "0644" "" || ok=0
        install_step 12 "/usr/share/applications/armbiandesk-files.desktop" "$share_dir/share/applications/armbiandesk-files.desktop" "0644" "" || ok=0
    fi

    if [ "$ok" -eq 1 ]; then
        local user_owner="${uid}:${gid}"
        install_step 13 "${home_dir}/.config/armbiandesk/openbox/rc.xml" "$share_dir/share/openbox/rc.xml" "0644" "$user_owner" || ok=0
        install_step 14 "${home_dir}/.config/armbiandesk/openbox/menu.xml" "$share_dir/share/openbox/menu.xml" "0644" "$user_owner" || ok=0
        install_step 15 "${home_dir}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" "$share_dir/share/xfce4/xfce4-panel.xml" "0644" "$user_owner" || ok=0
        install_step 16 "${home_dir}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" "$share_dir/share/xfce4/xfwm4.xml" "0644" "$user_owner" || ok=0
        install_step 17 "${home_dir}/.local/share/plank/themes/ArmbianDesk/dock.theme" "$share_dir/share/plank/dock.theme" "0644" "$user_owner" || ok=0
        install_step 18 "${home_dir}/.config/plank/dock1/launchers/armbiandesk-browser.dockitem" "$share_dir/share/plank/launchers/armbiandesk-browser.dockitem" "0644" "$user_owner" || ok=0
        install_step 19 "${home_dir}/.config/plank/dock1/launchers/armbiandesk-files.dockitem" "$share_dir/share/plank/launchers/armbiandesk-files.dockitem" "0644" "$user_owner" || ok=0
    fi

    if [ "$ok" -eq 1 ] && [ "$enable_autologin" -eq 1 ]; then
        local tmp_al
        tmp_al="$(mktemp)"
        cat >"$tmp_al" <<EOF
# Managed by ArmbianDesk (--enable-autologin)
[Seat:*]
autologin-user=$target_user
autologin-user-timeout=0
user-session=armbiandesk
EOF
        install_step 20 "/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf" "$tmp_al" "0644" "" || ok=0
        rm -f "$tmp_al"
    fi

    if [ "$ok" -ne 1 ]; then
        ad_rollback_manifest_partial "$destdir" "$backup_dir" "$run_manifest"
        ad_die "Install aborted and rolled back cleanly (partial manifest preserved at $run_manifest)."
    fi

    # Fix home subdirectories ownership if running as root
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        chown -R "${uid}:${gid}" \
            "${destdir}${home_dir}/.config/armbiandesk" \
            "${destdir}${home_dir}/.local/share/plank" \
            "${destdir}${home_dir}/.config/plank" 2>/dev/null || true
    fi

    # Keep active manifest idempotent (merge / deduplicate by rel_path, retaining earliest EXIST origin)
    python3 - "$active_manifest" "$run_manifest" <<'PY'
import os, sys
active_path, run_path = sys.argv[1:3]
records = {}
order = []
if os.path.isfile(active_path):
    with open(active_path, "r", encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) == 7:
                records[parts[1]] = parts
                order.append(parts[1])
with open(run_path, "r", encoding="utf-8") as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) == 7:
            rel = parts[1]
            if rel in records:
                # Keep original pre-install kind/sha/mode/uid/gid, update installed sha
                records[rel][6] = parts[6]
            else:
                records[rel] = parts
                order.append(rel)
with open(active_path, "w", encoding="utf-8") as fh:
    for rel in order:
        fh.write("\t".join(records[rel]) + "\n")
PY
    chmod 0600 "$active_manifest"

    ad_log "Install complete. Backup ID: $backup_id"
}

ad_cmd_uninstall() {
    local target_user="" destdir="" dry_run=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --user) target_user="${2:-}"; shift 2 ;;
            --destdir|--root) destdir="${2:-}"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            -h|--help) ad_install_usage; return 0 ;;
            *) ad_die "Unknown uninstall option: $1" ;;
        esac
    done

    destdir="$(ad_normalize_destdir "$destdir")"
    ad_guard_fixture_only "$destdir"

    if [ -n "$target_user" ]; then
        ad_resolve_user "$target_user" "$destdir" >/dev/null || return 1
    fi

    local state_dir="${destdir}/var/lib/armbiandesk"
    local active_manifest="$state_dir/installed-manifest.tsv"
    if [ ! -f "$active_manifest" ]; then
        ad_log "ArmbianDesk is not installed (no manifest at $active_manifest); nothing to remove."
        return 0
    fi

    echo "=== ArmbianDesk Uninstall Plan ==="
    echo "Manifest: $active_manifest"
    while IFS=$'\t' read -r kind rel_path _rest; do
        [ -n "$rel_path" ] || continue
        echo "  - remove ${destdir}${rel_path}"
    done <"$active_manifest"
    echo "Preserved: browser profile, user documents, SSH, stock sessions, and shared packages."

    if [ "$dry_run" -eq 1 ]; then
        echo "[dry-run] No files removed."
        return 0
    fi

    tac "$active_manifest" | while IFS=$'\t' read -r kind rel_path _rest; do
        [ -n "$rel_path" ] || continue
        ad_assert_safe_target "$destdir" "$rel_path"
        rm -f "${destdir}${rel_path}"
    done
    rm -f "$active_manifest"
    ad_log "ArmbianDesk files removed cleanly."
}

ad_cmd_restore() {
    local backup_id="" destdir="" dry_run=0 force=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --backup) backup_id="${2:-}"; shift 2 ;;
            --destdir|--root) destdir="${2:-}"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            --force) force=1; shift ;;
            -h|--help) ad_install_usage; return 0 ;;
            *) ad_die "Unknown restore option: $1" ;;
        esac
    done

    [ -n "$backup_id" ] || ad_die "--backup ID is required"
    ad_validate_ident "$backup_id" "backup ID"

    destdir="$(ad_normalize_destdir "$destdir")"
    ad_guard_fixture_only "$destdir"

    local backup_dir="${destdir}/var/lib/armbiandesk/backups/${backup_id}"
    local manifest="$backup_dir/manifest.tsv"
    [ -d "$backup_dir" ] && [ -f "$manifest" ] || ad_die "Backup ID not found: $backup_id"

    local conflicts=0
    echo "=== ArmbianDesk Restore Plan ($backup_id) ==="
    while IFS=$'\t' read -r kind rel_path orig_sha orig_mode orig_uid orig_gid inst_sha; do
        [ -n "$rel_path" ] || continue
        ad_assert_safe_target "$destdir" "$rel_path"
        local abs_target="${destdir}${rel_path}"
        if [ -f "$abs_target" ] && [ "$inst_sha" != "PENDING" ]; then
            local cur_sha
            cur_sha="$(sha256sum "$abs_target" | awk '{print $1}')"
            if [ "$cur_sha" != "$inst_sha" ]; then
                conflicts=$((conflicts + 1))
                if [ "$force" -eq 1 ]; then
                    echo "  - [CONFLICT OVERWRITE] ${abs_target} modified since install"
                else
                    echo "  - [CONFLICT SKIP] ${abs_target} modified since install (pass --force to overwrite)"
                    continue
                fi
            fi
        fi
        echo "  - [$kind] restore ${abs_target}"
    done <"$manifest"

    if [ "$dry_run" -eq 1 ]; then
        echo "[dry-run] Conflicts detected: $conflicts. No files modified."
        return 0
    fi

    while IFS=$'\t' read -r kind rel_path orig_sha orig_mode orig_uid orig_gid inst_sha; do
        [ -n "$rel_path" ] || continue
        local abs_target="${destdir}${rel_path}"
        if [ -f "$abs_target" ] && [ "$inst_sha" != "PENDING" ]; then
            local cur_sha
            cur_sha="$(sha256sum "$abs_target" | awk '{print $1}')"
            if [ "$cur_sha" != "$inst_sha" ] && [ "$force" -ne 1 ]; then
                ad_warn "Skipping modified file (conflict): $abs_target"
                continue
            fi
        fi
        if [ "$kind" = "NEW" ]; then
            rm -f "$abs_target"
        elif [ "$kind" = "EXIST" ]; then
            local bfile="$backup_dir/files${rel_path}"
            [ -f "$bfile" ] || ad_die "Missing backup payload: $bfile"
            local bsha
            bsha="$(sha256sum "$bfile" | awk '{print $1}')"
            [ "$bsha" = "$orig_sha" ] || ad_die "Backup hash mismatch for $rel_path"
            mkdir -p "$(dirname "$abs_target")"
            cp -p "$bfile" "$abs_target"
            chmod "$orig_mode" "$abs_target" 2>/dev/null || true
            if [ "${EUID:-$(id -u)}" -eq 0 ]; then
                chown "${orig_uid}:${orig_gid}" "$abs_target" 2>/dev/null || true
            fi
        fi
    done <"$manifest"

    ad_log "Restore completed for $backup_id (conflicts skipped/overwritten: $conflicts)."
}

ad_cmd_profile() {
    local sub="${1:-}" target_profile="${2:-}" destdir=""
    shift 2 2>/dev/null || true
    while [ $# -gt 0 ]; do
        case "$1" in
            --destdir|--root) destdir="${2:-}"; shift 2 ;;
            *) ad_die "Unknown profile option: $1" ;;
        esac
    done

    [ "$sub" = "set" ] || ad_die "Usage: armbiandesk profile set <minimal|desktop>"
    case "$target_profile" in
        minimal|desktop) ;;
        *) ad_die "Profile must be 'minimal' or 'desktop'" ;;
    esac

    destdir="$(ad_normalize_destdir "$destdir")"
    ad_guard_fixture_only "$destdir"

    local cfg_file="${destdir}/etc/armbiandesk/armbiandesk.conf"
    if [ ! -f "$cfg_file" ]; then
        local share_dir
        share_dir="$(ad_find_share_dir)" || ad_die "Config missing and share dir not found."
        mkdir -p "$(dirname "$cfg_file")"
        cp "$share_dir/config/armbiandesk.conf.example" "$cfg_file"
    fi

    local tmp_cfg
    tmp_cfg="$(mktemp)"
    sed "s|^PROFILE=.*|PROFILE=${target_profile}|" "$cfg_file" >"$tmp_cfg"
    ad_atomic_write "$cfg_file" "0644" <"$tmp_cfg"
    rm -f "$tmp_cfg"

    ad_log "Configured profile set to '$target_profile' (takes effect on next ArmbianDesk login; active session untouched)."
}
