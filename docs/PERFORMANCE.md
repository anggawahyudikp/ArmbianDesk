# Performance & Low-RAM Notes

## Design Principles for ~1 GB RAM Devices
1. **Minimal Profile Default**: `openbox` + static `feh` root pixmap wallpaper uses substantially less RSS/PSS than full desktop environments with compositors.
2. **Compositor Off**: `xfwm4 --compositor=off --vblank=off` and Plank `ZoomEnabled=false` eliminate GPU/CPU frame compositing overhead in `desktop` profile.
3. **Preserve Browser Security**: ArmbianDesk intentionally avoids disabling Chromium's sandbox (`--no-sandbox`), site isolation, or update/phishing protections to artificially lower RAM numbers.
4. **Accurate Memory Accounting**:
   - Use `MemAvailable` and `/proc/pressure/memory` (PSI) alongside `pswpin`/`pswpout` deltas rather than summing multiprocess `RSS` values (which double-count shared pages).
   - High `zram` usage alone does not indicate failure; monitor compressed physical cost (`zram/mm_stat`) and swap churn.
   - `cma=64M` in `extlinux.conf.in` avoids reserving 256 MiB for hardware video pools when software rendering/decoding is used.

## Running the Read-Only Benchmark Collector
```bash
./bin/armbiandesk benchmark --duration 60 --interval 2 --output ./benchmarks
```
See [BENCHMARK.md](../BENCHMARK.md) for the controlled A/B workload methodology (`T12`).
