<h1 align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk">
    <img src="logo.svg" alt="ArmbianDesk" width="128" height="128" />
    <br />
    ArmbianDesk
  </a>
</h1>

<p align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/releases/latest"><img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/anggawahyudikp/ArmbianDesk?sort=semver"></a>
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/anggawahyudikp/ArmbianDesk/ci.yml?branch=main"></a>
  <img src="https://img.shields.io/github/license/anggawahyudikp/ArmbianDesk" alt="MIT License" />
</p>

<p align="center">
The lightweight browser desktop & bootable USB toolkit for Armbian ARM64 TV boxes.
</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="#bootable-usb-in-one-command">Bootable USB</a> ·
  <a href="README.id.md">Bahasa Indonesia</a> ·
  <a href="docs/HARDWARE.md">Hardware Matrix</a>
</p>

---

ArmbianDesk turns a ~1 GB RAM Armbian/Debian/Ubuntu ARM64 device (such as observed ZTE B860H S905X hardware) into a fast, browser-first desktop — **or builds a complete bootable USB flashdisk `.img` from scratch** with `debootstrap` and ArmbianDesk pre-installed.

## Profiles That Fit 1 GB RAM.

Choose the session weight that matches your hardware:

- **`minimal`** *(default)* — `openbox`, static SVG wallpaper (`feh`), lightweight clock (`xclock`), Browser & Files launchers, and zero compositor or resident dock overhead.
- **`desktop`** *(opt-in)* — `xfwm4 --compositor=off`, one functional `xfce4-panel` top bar, and one centered `plank` bottom dock with intelligent auto-hide (animations, zoom, and startup sounds off). Automatic fallback to `minimal` if `xfwm4` fails startup.

## Bootable USB, Ready in One Command.

Need to boot straight from a USB flashdisk? `armbiandesk-image` creates a clean dual-partition `.img` (`ARMBIAN_BOOT` FAT32 + `ARMBIAN_ROOT` ext4) using `debootstrap` (`arm64`), a user-supplied donor Armbian/Amlogic kernel & `u-boot.ext` (or custom `--kernel-tar`), compiled U-Boot autoscripts, `zram` + `earlyoom`, and ArmbianDesk pre-configured.

```bash
# 1. Preview the build plan (no root required)
./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --dry-run

# 2. Build the bootable .img (requires sudo, debootstrap, qemu-user-static, u-boot-tools)
HASH="$(openssl passwd -6)"
sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm --profile minimal \
  --user deskuser --password-hash "$HASH" \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --output ./out/armbiandesk-usb.img --compress

# 3. Flash safely to a removable USB drive + verify SHA-256 readback
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```

> **Stock Android TV Boxes:** Some B860H revisions require USB-boot activation before stock U-Boot probes USB drives. See [docs/HARDWARE.md](docs/HARDWARE.md) and the optional experimental helper in [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md).

## Get started

Already booted into Armbian ARM64 X11? Install ArmbianDesk onto your live system in two steps:

```bash
# Preview target paths without touching the filesystem
./bin/armbiandesk install --user USER --profile minimal --dry-run

# Install (registers LightDM session without altering active sessions or enabling autologin)
sudo ./bin/armbiandesk install --user USER --profile minimal
```

Pass `--enable-autologin` if you want an isolated LightDM drop-in, or switch profiles any time with `sudo armbiandesk profile set desktop`. See [docs/INSTALL.md](docs/INSTALL.md) and [docs/UNINSTALL.md](docs/UNINSTALL.md) for backup, restore, and rollback commands.

## Sandboxed & Safe by Design.

- **No `--no-sandbox` shortcuts** — Chromium runs as an unprivileged user with OS sandboxing and site isolation intact.
- **Data-only configuration** — [`armbiandesk.conf`](config/armbiandesk.conf.example) is validated by a strict whitelist parser (`lib/config.sh`), never `source`d or `eval`ed as shell.
- **Atomic backups & rollback** — `install` creates `0600` manifests, rolls back partial writes on failure, preserves browser profiles on `uninstall`, and detects local edits during `restore`.
- **Safe USB flashing** — `armbiandesk-image flash` rejects non-removable disks (`RM != 1`) and OS mounts before writing.

## Documentation

- [Image Builder Guide](docs/IMAGE_BUILDER.md) · [Install](docs/INSTALL.md) · [Uninstall & Restore](docs/UNINSTALL.md)
- [Hardware Matrix & Limits](docs/HARDWARE.md) · [Performance](docs/PERFORMANCE.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Privacy](docs/PRIVACY.md) · [Assets & Provenance](docs/ASSETS.md) · [Test Report](TEST_REPORT.md) · [Benchmark Methodology](BENCHMARK.md)

## Contribute

Bug reports, hardware revision reports, and pull requests are welcome. Run `./tests/run-all.sh` before submitting and see [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## Credits

Licensed under the [MIT License](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for external distribution packages and upstream licenses.
