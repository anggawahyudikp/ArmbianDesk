#!/usr/bin/env bash
# Strict data-only configuration parser for ArmbianDesk.
# Never sources or evals configuration files.

ad_parse_config() {
    local cfg_file="$1"
    local allow_missing="${2:-0}"

    if [ ! -e "$cfg_file" ]; then
        if [ "$allow_missing" = "1" ]; then
            ad_load_config_defaults
            return 0
        fi
        ad_err "Configuration file not found: $cfg_file"
        return 1
    fi

    local parsed
    if ! parsed="$(python3 - "$cfg_file" <<'PY'
import os, re, shlex, stat, sys
from urllib.parse import urlparse

cfg_path = sys.argv[1]

if os.path.islink(cfg_path):
    sys.stderr.write(f"error: refusing symlink config file: {cfg_path}\n")
    sys.exit(2)

if not os.path.isfile(cfg_path):
    sys.stderr.write(f"error: config path is not a regular file: {cfg_path}\n")
    sys.exit(2)

st = os.stat(cfg_path)
if os.geteuid() == 0 and (st.st_mode & stat.S_IWOTH):
    sys.stderr.write(f"error: refusing world-writable config file as root: {cfg_path}\n")
    sys.exit(2)

defaults = {
    "PROFILE": "minimal",
    "START_URL": "https://example.org/",
    "BROWSER_AUTOSTART": "true",
    "BROWSER_BINARY": "auto",
    "BROWSER_COMPATIBILITY": "standard",
    "LANGUAGE": "en_US.UTF-8",
    "DISPLAY_MODE": "auto",
    "KEEP_AWAKE": "true",
    "DOCK_AUTOHIDE": "true",
    "DOCK_ZOOM": "false",
    "ENABLE_COMPOSITOR": "false",
    "STARTUP_SOUND": "false",
}

allowed_keys = set(defaults.keys())
seen_keys = set()
values = dict(defaults)

with open(cfg_path, "r", encoding="utf-8", newline="") as fh:
    raw_text = fh.read()

if "\r" in raw_text or "\0" in raw_text:
    sys.stderr.write("error: CR or NUL characters are not permitted in config file\n")
    sys.exit(2)

raw_lines = raw_text.split("\n")

for lineno, raw_line in enumerate(raw_lines, start=1):
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if "=" not in raw_line:
        sys.stderr.write(f"error: line {lineno}: expected KEY=VALUE\n")
        sys.exit(2)

    key, val = raw_line.split("=", 1)
    key = key.strip()
    if not re.fullmatch(r"[A-Z0-9_]+", key):
        sys.stderr.write(f"error: line {lineno}: invalid key syntax '{key}'\n")
        sys.exit(2)
    if key not in allowed_keys:
        sys.stderr.write(f"error: line {lineno}: unknown config key '{key}'\n")
        sys.exit(2)
    if key in seen_keys:
        sys.stderr.write(f"error: line {lineno}: duplicate config key '{key}'\n")
        sys.exit(2)
    seen_keys.add(key)

    # Reject control chars (including CR/LF/NUL)
    if any(ord(c) < 32 or ord(c) == 127 for c in val):
        sys.stderr.write(f"error: line {lineno}: control characters not allowed in {key}\n")
        sys.exit(2)

    # Strip optional matching single/double quotes without shell expansion
    val_stripped = val.strip()
    if len(val_stripped) >= 2 and (
        (val_stripped[0] == '"' and val_stripped[-1] == '"')
        or (val_stripped[0] == "'" and val_stripped[-1] == "'")
    ):
        val_stripped = val_stripped[1:-1]

    # Reject shell substitution markers in data fields
    for forbidden in ("$(", "${", "`"):
        if forbidden in val_stripped:
            sys.stderr.write(f"error: line {lineno}: shell substitution not allowed in {key}\n")
            sys.exit(2)

    if key == "PROFILE":
        if val_stripped not in ("minimal", "desktop"):
            sys.stderr.write(f"error: line {lineno}: PROFILE must be 'minimal' or 'desktop'\n")
            sys.exit(2)
    elif key in ("BROWSER_AUTOSTART", "KEEP_AWAKE", "DOCK_AUTOHIDE", "DOCK_ZOOM", "ENABLE_COMPOSITOR", "STARTUP_SOUND"):
        if val_stripped not in ("true", "false"):
            sys.stderr.write(f"error: line {lineno}: {key} must be literal 'true' or 'false'\n")
            sys.exit(2)
    elif key == "BROWSER_COMPATIBILITY":
        if val_stripped not in ("standard", "software-rendering"):
            sys.stderr.write(f"error: line {lineno}: BROWSER_COMPATIBILITY must be 'standard' or 'software-rendering'\n")
            sys.exit(2)
    elif key == "START_URL":
        if val_stripped != "":
            if val_stripped.startswith("-"):
                sys.stderr.write(f"error: line {lineno}: START_URL cannot start with '-'\n")
                sys.exit(2)
            if any(ch.isspace() for ch in val_stripped):
                sys.stderr.write(f"error: line {lineno}: START_URL must not contain literal whitespace\n")
                sys.exit(2)
            parsed = urlparse(val_stripped)
            if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc:
                sys.stderr.write(f"error: line {lineno}: START_URL must be an http:// or https:// URL\n")
                sys.exit(2)
    elif key == "BROWSER_BINARY":
        if val_stripped != "auto":
            if not val_stripped.startswith("/") or ".." in val_stripped.split("/"):
                sys.stderr.write(f"error: line {lineno}: BROWSER_BINARY must be 'auto' or an absolute path without '..'\n")
                sys.exit(2)
    elif key == "LANGUAGE":
        if not re.fullmatch(r"[A-Za-z0-9_.@-]+", val_stripped):
            sys.stderr.write(f"error: line {lineno}: invalid LANGUAGE '{val_stripped}'\n")
            sys.exit(2)
    elif key == "DISPLAY_MODE":
        if val_stripped != "auto" and not re.fullmatch(r"[0-9]{3,5}x[0-9]{3,5}(@[0-9]{2,3}(\.[0-9]+)?)?", val_stripped):
            sys.stderr.write(f"error: line {lineno}: invalid DISPLAY_MODE '{val_stripped}'\n")
            sys.exit(2)

    values[key] = val_stripped

for k in sorted(values.keys()):
    print(f"AD_CFG_{k}={shlex.quote(values[k])}")
PY
)"; then
        return 1
    fi

    # Parsed lines come solely from shlex.quote on validated keys.
    while IFS= read -r line; do
        eval "$line"
    done <<< "$parsed"
    return 0
}

ad_load_config_defaults() {
    AD_CFG_PROFILE="minimal"
    AD_CFG_START_URL="https://example.org/"
    AD_CFG_BROWSER_AUTOSTART="true"
    AD_CFG_BROWSER_BINARY="auto"
    AD_CFG_BROWSER_COMPATIBILITY="standard"
    AD_CFG_LANGUAGE="en_US.UTF-8"
    AD_CFG_DISPLAY_MODE="auto"
    AD_CFG_KEEP_AWAKE="true"
    AD_CFG_DOCK_AUTOHIDE="true"
    AD_CFG_DOCK_ZOOM="false"
    AD_CFG_ENABLE_COMPOSITOR="false"
    AD_CFG_STARTUP_SOUND="false"
}

# Load system config then optional user override config (user cannot alter binary/system paths if disallowed).
ad_load_effective_config() {
    local destdir="${1:-}"
    local user_cfg="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/armbiandesk/armbiandesk.conf}"
    local sys_cfg="$destdir/etc/armbiandesk/armbiandesk.conf"

    ad_load_config_defaults
    if [ -f "$sys_cfg" ]; then
        ad_parse_config "$sys_cfg" || return 1
    fi
    if [ -n "$user_cfg" ] && [ -f "$user_cfg" ]; then
        # Preserve system-level BROWSER_BINARY if user override tries to change it when running privileged?
        ad_parse_config "$user_cfg" || return 1
    fi
    return 0
}
