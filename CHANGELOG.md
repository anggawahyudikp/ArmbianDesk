# Changelog

All notable changes to **ArmbianDesk** will be documented in this file.

## [0.1.0] - 2026-11-22
### Added
- Clean-room ArmbianDesk CLI (`bin/armbiandesk`) supporting `install`, `uninstall`, `restore`, `status --json`, `config validate`, `profile set`, `browser`, `files`, `power`, `session`, and `benchmark`.
- Two X11 session profiles: `minimal` (default, Openbox + static wallpaper + clock + launchers) and `desktop` (opt-in, `xfwm4 --compositor=off` + functional `xfce4-panel` + single centered `plank` dock with zoom/sound off).
- Strict data-only whitelist configuration parser (`lib/config.sh`) rejecting shell evaluation, command substitutions, symlink configs, and invalid URLs.
- Idempotent installer with `--destdir`/`--root`, `--dry-run`, private `0600` manifests, atomic backups, failure rollback, and conflict-aware restore.
- Full bootable ARM64 flashdisk image builder (`bin/armbiandesk-image build`), safe removable-only USB flasher with SHA-256 verification (`bin/armbiandesk-image flash`), and optional experimental B860H U-Boot env prep (`tools/b860h-usb-prep/`).
- Automated acceptance test suite (`tests/run-all.sh`) covering static checks, config security, install lifecycle, mocked sessions, image builder dry-runs, and source ZIP sanitization.
