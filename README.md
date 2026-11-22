# ArmbianDesk

**ArmbianDesk** is an open-source, lightweight X11 browser-focused desktop toolkit and bootable ARM64 USB flashdisk image builder designed for resource-constrained Armbian TV boxes / single-board computers (~1 GB RAM).

> **Scope & Prerequisite Note:** ArmbianDesk's core desktop layer (`armbiandesk`) runs on an already-booted Armbian/Debian/Ubuntu ARM64 X11 userland. For users who want to create a **bootable USB flashdisk directly**, `armbiandesk-image` provides a full image builder (`debootstrap` ARM64 rootfs + kernel/DTB/U-Boot bootchain from a verified donor image or tarball + pre-installed ArmbianDesk) and a safe removable-only USB writer. Booting from USB on stock Android boxes (such as certain ZTE B860H revisions) may require prior USB-boot enabling on the box; see [docs/HARDWARE.md](docs/HARDWARE.md) and [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md).

## Features (v0.1.0)
- **Two Desktop Profiles**:
  - `minimal` *(default)*: `openbox` window manager, static SVG wallpaper (`feh`), digital clock (`xclock`), Browser & Files launchers, zero compositor/dock overhead.
  - `desktop` *(opt-in)*: `xfwm4 --compositor=off`, one functional top `xfce4-panel` (Applications menu, window buttons, clock), and one centered `plank` bottom dock (`intelligent` auto-hide, zoom/sound off).
- **Full Bootable Flashdisk Builder (`armbiandesk-image`)**:
  - Builds a dual-partition `.img` (`ARMBIAN_BOOT` FAT32 + `ARMBIAN_ROOT` ext4) from scratch with `debootstrap`, `qemu-aarch64-static`, `extlinux.conf`, compiled U-Boot scripts (`s905_autoscript`, `aml_autoscript`), `zram-tools`, `earlyoom`, and ArmbianDesk pre-installed.
  - Safe USB flasher (`armbiandesk-image flash`) refuses non-removable disks or OS mounts and verifies written bytes via SHA-256 readback.
- **Security & Reliability by Design**:
  - Strict data-only configuration parser (never `source`s or `eval`s config files).
  - Sandboxed browser execution as a regular non-root user (`--no-sandbox` is never used; site isolation stays enabled).
  - Idempotent install/uninstall/restore with `--dry-run`, `--destdir`/`--root`, `0600` private manifests, conflict detection, and automatic rollback on failure.

## Quick Start

### 1. Build a Bootable USB Flashdisk Image
```bash
# Dry-run plan first (no root required)
./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --dry-run

# Build the bootable .img (requires sudo, debootstrap, qemu-user-static, u-boot-tools)
sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --output ./out/armbiandesk-usb.img

# Flash safely to USB drive /dev/sdX (replace sdX with your actual removable USB drive)
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```
See [docs/IMAGE_BUILDER.md](docs/IMAGE_BUILDER.md) for full options and kernel tarball inputs.

### 2. Install Onto an Existing Booted Armbian System
```bash
# Preview install plan without modifying system files
./bin/armbiandesk install --user USER --profile minimal --dry-run

# Install ArmbianDesk (registers LightDM session without changing existing sessions)
sudo ./bin/armbiandesk install --user USER --profile minimal

# Optional: enable autologin into ArmbianDesk via isolated LightDM drop-in
sudo ./bin/armbiandesk install --user USER --profile minimal --enable-autologin
```

### 3. Manage & Inspect
```bash
armbiandesk status --json
armbiandesk config validate --file /etc/armbiandesk/armbiandesk.conf
sudo armbiandesk profile set desktop
armbiandesk benchmark --duration 60 --output ./benchmarks
sudo armbiandesk uninstall --user USER
sudo armbiandesk restore --backup BACKUP_ID
```

## Documentation
- Indonesian guide: [README.id.md](README.id.md)
- Install & Uninstall: [docs/INSTALL.md](docs/INSTALL.md), [docs/UNINSTALL.md](docs/UNINSTALL.md)
- Flashdisk Image Builder: [docs/IMAGE_BUILDER.md](docs/IMAGE_BUILDER.md)
- Hardware Matrix & Limits: [docs/HARDWARE.md](docs/HARDWARE.md)
- Performance & Benchmarks: [docs/PERFORMANCE.md](docs/PERFORMANCE.md), [BENCHMARK.md](BENCHMARK.md)
- Troubleshooting & Privacy: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), [docs/PRIVACY.md](docs/PRIVACY.md)
- Assets & Third-Party Notices: [docs/ASSETS.md](docs/ASSETS.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
