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
  <a href="LICENSE"><img src="https://img.shields.io/github/license/anggawahyudikp/ArmbianDesk" alt="MIT License" /></a>
</p>

<p align="center">
The lightweight browser desktop &amp; bootable USB toolkit for Armbian ARM64 TV boxes.
</p>

<p align="center">
  <a href="https://github.com/anggawahyudikp/ArmbianDesk/releases/latest">Download v0.1.0</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="#bootable-usb-dialed-in">Bootable USB</a> ·
  <a href="README.id.md">Bahasa Indonesia</a> ·
  <a href="docs/HARDWARE.md">Hardware Matrix</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/hero-light.png">
    <img alt="ArmbianDesk X11 desktop session and bootable USB image builder" src="docs/images/hero-light.png" width="880">
  </picture>
</p>

<p align="center">
Turn a 1 GB RAM ARM64 TV box (such as ZTE B860H S905X hardware) into a clean, browser-first workstation —<br/>
install onto an existing Armbian X11 system or build a ready-to-flash USB <code>.img</code> from scratch.
</p>

---

<h2 align="center">Profiles That Fit 1 GB.</h2>

<p align="center">
Different hardware budgets deserve different session weights.<br/>
Switch cleanly between a zero-overhead Openbox workspace and a familiar panel + dock layout.
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/profiles-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/profiles-light.png">
    <img alt="Comparison between minimal and desktop profiles" src="docs/images/profiles-light.png" width="880">
  </picture>
</p>

- **`minimal`** *(default)* — `openbox`, static SVG wallpaper (`feh`), lightweight clock (`xclock`), Browser & Files launchers, zero compositor or resident dock overhead.
- **`desktop`** *(opt-in)* — `xfwm4 --compositor=off`, one functional `xfce4-panel` top bar, one centered `plank` bottom dock with intelligent auto-hide (animations, zoom, and startup sounds off), and automatic fallback to `minimal` if `xfwm4` fails.

---

<h2 align="center">Bootable USB, Dialed In.</h2>

<p align="center">
Build a clean dual-partition ARM64 <code>.img</code> from scratch with <code>debootstrap</code>,<br/>
donor kernel &amp; <code>u-boot.ext</code>, compiled U-Boot autoscripts, <code>zram</code> + <code>earlyoom</code>, and ArmbianDesk pre-installed.
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/usb-pipeline-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/usb-pipeline-light.png">
    <img alt="Three-step bootable USB image build and verified flash pipeline" src="docs/images/usb-pipeline-light.png" width="880">
  </picture>
</p>

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

> **Stock Android TV Boxes:** Some ZTE B860H revisions require USB-first-boot activation before stock U-Boot probes USB drives. Read [docs/HARDWARE.md](docs/HARDWARE.md) and the optional experimental helper in [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md) carefully before touching eMMC U-Boot variables.

---

<h2 align="center">Sandboxed &amp; Safe by Design.</h2>

| Guarantee | How ArmbianDesk Enforces It |
| --- | --- |
| **OS Browser Sandboxing** | Chromium runs strictly as an unprivileged user — zero `--no-sandbox` shortcuts; site isolation stays enabled. |
| **Data-Only Configuration** | [`armbiandesk.conf`](config/armbiandesk.conf.example) is validated by a strict whitelist parser (`lib/config.sh`), never `source`d or `eval`ed as shell. |
| **Atomic Backups &amp; Rollback** | `install` writes `0600` backup manifests, rolls back partial writes on error, preserves browser profiles on `uninstall`, and checks local edits on `restore`. |
| **Safe Removable-Disk Flasher** | `armbiandesk-image flash` rejects internal disks (`RM != 1`) and active OS mounts before writing a single byte. |

---

## Get started

Already running Armbian ARM64 with X11? [Download ArmbianDesk v0.1.0](https://github.com/anggawahyudikp/ArmbianDesk/releases/latest) or clone and install directly:

```bash
# Preview target paths without modifying your system
./bin/armbiandesk install --user USER --profile minimal --dry-run

# Install (registers LightDM session without touching active sessions or enabling autologin)
sudo ./bin/armbiandesk install --user USER --profile minimal
```

Pass `--enable-autologin` for an isolated LightDM drop-in, or switch profiles any time with `sudo armbiandesk profile set desktop`. Full backup, restore, and rollback commands are documented in [docs/INSTALL.md](docs/INSTALL.md) and [docs/UNINSTALL.md](docs/UNINSTALL.md).

## Documentation

| Topic | Guide |
| --- | --- |
| Bootable USB & Image Builder | [docs/IMAGE_BUILDER.md](docs/IMAGE_BUILDER.md) · [tools/b860h-usb-prep/README.md](tools/b860h-usb-prep/README.md) |
| Install, Restore & Troubleshooting | [docs/INSTALL.md](docs/INSTALL.md) · [docs/UNINSTALL.md](docs/UNINSTALL.md) · [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Hardware, Performance & Reports | [docs/HARDWARE.md](docs/HARDWARE.md) · [docs/PERFORMANCE.md](docs/PERFORMANCE.md) · [TEST_REPORT.md](TEST_REPORT.md) · [BENCHMARK.md](BENCHMARK.md) |
| Privacy & Asset Provenance | [docs/PRIVACY.md](docs/PRIVACY.md) · [docs/ASSETS.md](docs/ASSETS.md) · [DECISIONS.md](DECISIONS.md) |

## Contribute

Bug reports, board/DTB compatibility notes, and pull requests are welcome. Run `./tests/run-all.sh` before submitting and read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## Credits

Released under the [MIT License](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for external packages and upstream licenses.
