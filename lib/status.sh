#!/usr/bin/env bash
# Sanitized observability output (`armbiandesk status --json`).
# Deliberately excludes URLs, window/chat titles, IPs, MACs, SSIDs, and user identifying paths.

ad_cmd_status() {
    local as_json=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) as_json=1; shift ;;
            *) ad_die "Unknown status option: $1" ;;
        esac
    done

    ad_load_effective_config "" || ad_load_config_defaults

    python3 - "$ARMBIANDESK_VERSION" "$AD_CFG_PROFILE" "$AD_CFG_BROWSER_COMPATIBILITY" "$as_json" <<'PY'
import json, os, platform, shutil, sys

version, profile, compat, as_json = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

def read_first(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().strip()
    except OSError:
        return None

meminfo = {}
raw_mem = read_first("/proc/meminfo") or ""
for line in raw_mem.splitlines():
    if ":" in line:
        k, v = line.split(":", 1)
        parts = v.strip().split()
        if parts and parts[0].isdigit():
            meminfo[k] = int(parts[0]) # KiB

temp_c = None
for tz in ("/sys/class/thermal/thermal_zone0/temp", "/sys/class/thermal/thermal_zone1/temp"):
    t = read_first(tz)
    if t and t.lstrip("-").isdigit():
        temp_c = round(int(t) / 1000.0, 1)
        break

load1, load5, load15 = (None, None, None)
raw_load = read_first("/proc/loadavg")
if raw_load:
    parts = raw_load.split()
    if len(parts) >= 3:
        load1, load5, load15 = float(parts[0]), float(parts[1]), float(parts[2])

zram_orig_bytes = 0
zram_compr_bytes = 0
zram_mem_used_bytes = 0
try:
    for name in os.listdir("/sys/block"):
        if name.startswith("zram"):
            mm = read_first(f"/sys/block/{name}/mm_stat")
            if mm:
                cols = mm.split()
                if len(cols) >= 3:
                    zram_orig_bytes += int(cols[0])
                    zram_compr_bytes += int(cols[1])
                    zram_mem_used_bytes += int(cols[2])
except OSError:
    pass

data = {
    "product": "ArmbianDesk",
    "version": version,
    "arch": platform.machine(),
    "kernel": platform.release(),
    "configured_profile": profile,
    "browser_compatibility": compat,
    "installed": os.path.isfile("/var/lib/armbiandesk/installed-manifest.tsv"),
    "components": {
        "chromium": bool(shutil.which("chromium") or shutil.which("chromium-browser")),
        "openbox": bool(shutil.which("openbox")),
        "xfwm4": bool(shutil.which("xfwm4")),
        "xfce4_panel": bool(shutil.which("xfce4-panel")),
        "plank": bool(shutil.which("plank")),
        "thunar": bool(shutil.which("thunar")),
    },
    "resources": {
        "mem_total_kib": meminfo.get("MemTotal"),
        "mem_available_kib": meminfo.get("MemAvailable"),
        "mem_cached_kib": meminfo.get("Cached"),
        "swap_total_kib": meminfo.get("SwapTotal"),
        "swap_free_kib": meminfo.get("SwapFree"),
        "zram_orig_data_bytes": zram_orig_bytes,
        "zram_compr_data_bytes": zram_compr_bytes,
        "zram_mem_used_bytes": zram_mem_used_bytes,
        "load_avg": [load1, load5, load15],
        "temp_celsius": temp_c,
    },
}

if as_json:
    print(json.dumps(data, indent=2))
else:
    print(f"ArmbianDesk {version} ({data['arch']}, kernel {data['kernel']})")
    print(f"Profile: {profile} | Installed: {data['installed']}")
    print(f"MemAvailable: {data['resources']['mem_available_kib']} KiB / {data['resources']['mem_total_kib']} KiB | Temp: {temp_c} C")
PY
}
