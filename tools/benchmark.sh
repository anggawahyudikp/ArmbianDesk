#!/usr/bin/env bash
set -euo pipefail

# Read-only resource and performance collector for ArmbianDesk (T12).
# Never uses sudo, drop_caches, swapoff, browser restarts, or forced GC.

DURATION=60
INTERVAL=2
OUT_DIR=""

usage() {
    cat <<'EOF'
Usage: armbiandesk benchmark [--duration SEC] [--interval SEC] [--output DIR]

Collects read-only hardware/desktop telemetry without mutating system state:
  - CPU usage delta from /proc/stat (median & p95)
  - Memory pressure stall (PSI /proc/pressure/memory)
  - MemAvailable, Cached, Swap delta (pswpin/pswpout)
  - zram physical memory cost vs uncompressed orig_data_size
  - Temperature, loadavg, and PSS/SwapPSS of desktop/browser processes (if readable)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --duration) DURATION="${2:-60}"; shift 2 ;;
        --interval) INTERVAL="${2:-2}"; shift 2 ;;
        --output) OUT_DIR="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

python3 - "$DURATION" "$INTERVAL" "$OUT_DIR" <<'PY'
import json, os, platform, statistics, sys, time

duration = max(2, int(sys.argv[1]))
interval = max(1, int(sys.argv[2]))
out_dir = sys.argv[3]

def read_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""

def read_cpu_jiffies():
    line = read_file("/proc/stat").splitlines()[0]
    cols = [int(x) for x in line.split()[1:]]
    idle = cols[3] + (cols[4] if len(cols) > 4 else 0)
    total = sum(cols)
    return idle, total

def read_vmstat():
    res = {}
    for line in read_file("/proc/vmstat").splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            res[parts[0]] = int(parts[1])
    return res

def read_meminfo():
    res = {}
    for line in read_file("/proc/meminfo").splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            toks = v.strip().split()
            if toks and toks[0].isdigit():
                res[k] = int(toks[0])
    return res

def read_psi_mem():
    txt = read_file("/proc/pressure/memory")
    out = {}
    for line in txt.splitlines():
        parts = line.split()
        if parts and parts[0] in ("some", "full"):
            kv = {}
            for item in parts[1:]:
                if "=" in item:
                    k, v = item.split("=", 1)
                    kv[k] = float(v) if "." in v else int(v)
            out[parts[0]] = kv
    return out

def read_zram():
    orig = compr = mem_used = 0
    try:
        for dev in os.listdir("/sys/block"):
            if dev.startswith("zram"):
                mm = read_file(f"/sys/block/{dev}/mm_stat").strip()
                if mm:
                    cols = mm.split()
                    if len(cols) >= 3:
                        orig += int(cols[0])
                        compr += int(cols[1])
                        mem_used += int(cols[2])
    except OSError:
        pass
    return {"orig_bytes": orig, "compr_bytes": compr, "mem_used_bytes": mem_used}

def read_temp():
    for p in ("/sys/class/thermal/thermal_zone0/temp", "/sys/class/thermal/thermal_zone1/temp"):
        t = read_file(p).strip()
        if t and t.lstrip("-").isdigit():
            return round(int(t) / 1000.0, 1)
    return None

def read_proc_pss():
    targets = ("openbox", "xfwm4", "xfce4-panel", "plank", "chromium", "chrome", "thunar", "xclock")
    totals = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        comm = read_file(f"/proc/{pid}/comm").strip().lower()
        if not any(comm.startswith(t) for t in targets):
            continue
        smaps = read_file(f"/proc/{pid}/smaps_rollup")
        if not smaps:
            continue
        pss = swap_pss = 0
        for line in smaps.splitlines():
            if line.startswith("Pss:"):
                pss = int(line.split()[1])
            elif line.startswith("SwapPss:"):
                swap_pss = int(line.split()[1])
        entry = totals.setdefault(comm, {"procs": 0, "pss_kib": 0, "swap_pss_kib": 0})
        entry["procs"] += 1
        entry["pss_kib"] += pss
        entry["swap_pss_kib"] += swap_pss
    return totals

samples = max(1, duration // interval)
cpu_pcts = []
mem_avail_samples = []
psi_full_avg10 = []

vm_start = read_vmstat()
prev_idle, prev_total = read_cpu_jiffies()

for _ in range(samples):
    time.sleep(interval)
    cur_idle, cur_total = read_cpu_jiffies()
    d_total = max(1, cur_total - prev_total)
    d_idle = max(0, cur_idle - prev_idle)
    cpu_pct = round(100.0 * (d_total - d_idle) / d_total, 2)
    cpu_pcts.append(cpu_pct)
    prev_idle, prev_total = cur_idle, cur_total

    mi = read_meminfo()
    if "MemAvailable" in mi:
        mem_avail_samples.append(mi["MemAvailable"])
    psi = read_psi_mem()
    if "full" in psi and "avg10" in psi["full"]:
        psi_full_avg10.append(psi["full"]["avg10"])

vm_end = read_vmstat()
pswpin_delta = vm_end.get("pswpin", 0) - vm_start.get("pswpin", 0)
pswpout_delta = vm_end.get("pswpout", 0) - vm_start.get("pswpout", 0)

def p95(vals):
    if not vals:
        return None
    s = sorted(vals)
    idx = min(len(s) - 1, int(round(0.95 * (len(s) - 1))))
    return s[idx]

report = {
    "product": "ArmbianDesk",
    "arch": platform.machine(),
    "kernel": platform.release(),
    "duration_sec": samples * interval,
    "interval_sec": interval,
    "cpu_total_pct": {
        "median": round(statistics.median(cpu_pcts), 2) if cpu_pcts else None,
        "p95": p95(cpu_pcts),
        "samples": len(cpu_pcts),
    },
    "memory_kib": {
        "total": read_meminfo().get("MemTotal"),
        "available_min": min(mem_avail_samples) if mem_avail_samples else None,
        "available_median": round(statistics.median(mem_avail_samples), 1) if mem_avail_samples else None,
    },
    "swap_delta_pages": {
        "pswpin": pswpin_delta,
        "pswpout": pswpout_delta,
    },
    "psi_memory_full_avg10_max": max(psi_full_avg10) if psi_full_avg10 else None,
    "zram": read_zram(),
    "temp_celsius": read_temp(),
    "process_pss_kib": read_proc_pss(),
}

encoded = json.dumps(report, indent=2)
print(encoded)
if out_dir:
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, f"benchmark-{int(time.time())}.json")
    with open(out_file, "w", encoding="utf-8") as fh:
        fh.write(encoded + "\n")
    os.chmod(out_file, 0o600)
PY
