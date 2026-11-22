# ArmbianDesk v0.1.0 Release Checklist

- [x] New clean repository created outside legacy source repository with fresh git history.
- [x] All files use neutral `ArmbianDesk` / `armbiandesk` identity; zero legacy brand/domain/credential strings.
- [x] MIT `LICENSE` and `THIRD_PARTY_NOTICES.md` included.
- [x] Safe whitelist data-only config parser (`T02`) verified.
- [x] Idempotent install, `--dry-run`, backup, conflict-aware restore, and mid-install rollback (`T03`–`T06`) verified.
- [x] Session lifecycle (`minimal`, `desktop`, fallback, bounded crash recovery) tested in mock environment (`T07`–`T10`).
- [x] Bootable flashdisk builder `--dry-run`, USB flasher safety guards, and B860H CRC32 env patcher verified.
- [x] Source allowlist ZIP built, sanitized (`T13`), checksummed (`SHA-256`), and smoke-tested from clean extraction (`T15`).

## Pending / Blockers Before Hardware General Release
- [ ] **Real ARM64 Hardware Smoke (`T11`)**: Live cold boot of a freshly built flashdisk image on physical B860H / S905X hardware (`NOT RUN` in local x86_64 workspace; requires host `debootstrap` + `u-boot-tools` + `sudo` + target flashdisk & test STB).
- [ ] **Real Xvfb GUI Smoke**: Install `xvfb` and `shellcheck` in CI/host for live headless X server and full shell linting coverage.
- [ ] **Controlled ARM64 Desktop Benchmark (`T12` A–E)**: Run `./bin/armbiandesk benchmark` on a clean authorized ARM64 test unit for `minimal` vs `desktop` PSS/CPU/PSI comparisons.
