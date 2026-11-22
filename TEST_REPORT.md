# ArmbianDesk Test Report

- **Date**: 2026-11-22
- **Host Environment**: Linux x86_64 (`uname -m`: `x86_64`), Python 3, Bash
- **Missing Optional Host Tools**: `shellcheck`, `xvfb`, `debootstrap`, `u-boot-tools` (`mkimage`)

## Summary Results

| Test ID | Scope | Command | Result | Notes / Limitations |
|---|---|---|---|---|
| **T01** | Shell syntax (`bash -n` per file), XML, SVG, `.desktop`, config schema | `./tests/test_static.sh` | **PASS** | 20 shell files checked with `bash -n`; `shellcheck` skipped (not installed on host) |
| **T02** | Config parser safety, anti-injection (`$(...)`, backticks, CR/NUL, symlinks, unknown/duplicate keys) | `python3 ./tests/test_config_parser.py` | **PASS** | All valid and hostile payloads verified without shell execution |
| **T03** | `--dry-run` immutability (`install`, `uninstall`, `restore`) | `./tests/test_install_lifecycle.sh` | **PASS** | Pre/post SHA-256 fixture tree identical |
| **T04** | Idempotent double install, double uninstall, `0600` manifest, profile preservation | `./tests/test_install_lifecycle.sh` | **PASS** | Tested on non-1000 UID `1234` with spaces in home path (`/home/desk user`) |
| **T05** | Backup fidelity, conflict skip vs `--force`, mid-install simulated failure rollback | `./tests/test_install_lifecycle.sh` | **PASS** | Partial work cleanly rolled back; user edits preserved unless `--force` |
| **T06** | Non-root user checks, `--no-sandbox` absence, opt-in autologin | `./tests/test_install_lifecycle.sh`, `./tests/test_session_mock.sh` | **PASS** | Runtime flags verified under mock binary test |
| **T07** | Minimal profile lifecycle (`openbox`, `feh`, `xclock`, child cleanup on `TERM`) | `./tests/test_session_mock.sh` | **PASS** | Executed with mock X11/WM binaries (`Xvfb` not installed on host); unrelated user PID unaffected |
| **T08** | Desktop profile (`xfwm4 --compositor=off`, 1 `xfce4-panel`, 1 `plank`, zoom off) | `./tests/test_session_mock.sh` | **PASS** | Executed with mock X11/WM binaries |
| **T09** | Recovery (`xfwm4` early fail fallback to `minimal`, normal exit no respawn, bounded crash retry) | `./tests/test_session_mock.sh` | **PASS** | Normal exit `0` did not reopen; crash `1` stopped after bounded retries |
| **T10** | Offline startup (no blocking HTTP `HEAD` loop) | `./tests/test_session_mock.sh` | **PASS** | Browser launched directly without waiting on curl probes |
| **T11** | Physical hardware smoke (reboot, USB cold-boot, HDMI, audio, upload) | Manual on test STB | **NOT RUN** | Requires authorized physical ARM64 STB hardware; operational STB left untouched |
| **T12 (Collector)** | Read-only benchmark collector CLI (`tools/benchmark.sh`) | `./bin/armbiandesk benchmark --duration 2 --interval 1` | **PASS** | Collector JSON output verified on x86_64 host; controlled ARM64 A/B comparison is `NOT RUN` (see `BENCHMARK.md`) |
| **T13** | Privacy, secrets, CRLF, symlink, and private deny-list scan | `./tools/sanitize-check.sh .` | **PASS** | 58 files scanned; 0 issues |
| **T14** | License & asset provenance (`LICENSE`, `THIRD_PARTY_NOTICES.md`) | `./tests/test_release_sanitize.sh` | **PASS** | All bundled assets original MIT |
| **T15** | Allowlist ZIP build, SHA-256 verification, clean extraction smoke test | `./tests/test_release_sanitize.sh` | **PASS** | Cleanly builds and passes `T01`–`T06` & image dry-run tests from extracted archive |
| **IMG-01..04** | Full image builder `--dry-run`, USB flasher guard, B860H CRC32 env patcher, uImage boot verify | `./tests/test_image_builder.sh` | **PASS** | Real `debootstrap` ARM64 `.img` build (`NOT RUN` — requires host `sudo`, `debootstrap`, `u-boot-tools`) |
