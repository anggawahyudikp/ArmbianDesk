# Hardware Compatibility & Support Matrix

TV boxes sold under community names (such as "ZTE B860H") vary across board revisions (`v1`, `v2`, `v2.1`, `v5`), SoCs, Wi-Fi/BT chips, eMMC wiring, and stock U-Boot policies.

## Support Matrix

| Target / Scenario | Status | Notes |
|---|---|---|
| Booted Armbian ARM64 Debian/Ubuntu X11 (`minimal` / `desktop`) | **Primary Target** | Desktop layer designed for ~1 GB RAM ARM64 STBs |
| Observed reference device: ZTE B860H (`meson-gxl-s905x-p212`, 915 MiB RAM visible, kernel `6.18.45-current-meson64`) | **Observed Read-Only** | Runtime inventory verified; full cold-boot image build NOT RUN on test hardware yet |
| Other B860H revisions (S905X2 / S905L / different Wi-Fi chips) | **UNKNOWN / Experimental** | Requires selecting matching DTB (`--dtb`) and verifying boot on test hardware |
| Hardware video acceleration (VPU `meson_vdec` / Chromium GLES) | **Not Claimed** | Software rendering opt-in (`BROWSER_COMPATIBILITY=software-rendering`) is available if GPU causes instability |
| Stock Android U-Boot USB-first-boot patching (`tools/b860h-usb-prep/`) | **Experimental** | Only patch `/dev/block/env` after full backup + readback verification; carry risk of boot failure if offset/layout differs |

## Important Limits
- **Do not** promise smooth 4K60 or crash-free heavy web apps on 1 GB RAM ARM64 STBs.
- Always keep an unmodified distro login session available in LightDM for recovery.
