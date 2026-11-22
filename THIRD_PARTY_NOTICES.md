# Third-Party Notices & Dependencies

Original scripts, templates, configurations, and the neutral SVG wallpaper (`share/wallpapers/armbiandesk.svg`) in ArmbianDesk are licensed under the MIT License (see [LICENSE](LICENSE)).

ArmbianDesk does **not** bundle binary APT packages, proprietary wallpapers, vendor logos, startup sounds, or U-Boot binaries in its source distribution. When installed or built via `apt-get` / `debootstrap` on Debian or Ubuntu/Armbian, the following external packages are installed from your configured distribution repositories under their respective upstream licenses:

| Component | Purpose | Typical Distro License(s) |
|---|---|---|
| `openbox` | Minimal profile window manager | GPL-2.0+ |
| `xfwm4`, `xfce4-panel` | Desktop profile WM and top bar | GPL-2.0+ |
| `plank` | Desktop profile auto-hide bottom dock | GPL-3.0+ |
| `chromium` | Native ARM64 web browser (distro package) | BSD-3-Clause (and bundled component licenses) |
| `thunar`, `gvfs` | Lightweight graphical file manager | GPL-2.0+ / LGPL-2.0+ |
| `feh` | Static root pixmap wallpaper setter | MIT (feh license) |
| `xorg`, `x11-xserver-utils`, `x11-utils`, `x11-apps` | X11 display stack (`xrandr`, `xset`, `xprop`, `xclock`) | MIT / X11 |
| `wmctrl`, `xdotool` | Window focus and EWMH helpers | GPL-2.0+ / BSD-3-Clause |
| `zram-tools`, `earlyoom` | Compressed RAM swap and OOM safety | GPL-2.0+ / MIT |
| `debootstrap`, `qemu-user-static`, `u-boot-tools` | Host image build dependencies (build time only) | MIT / GPL-2.0+ |

Optional user-supplied inputs to `armbiandesk-image build` (`--boot-source-image` or `--kernel-tar` / `--uboot-dir`) retain the licenses of their respective Linux kernel (GPL-2.0) and U-Boot (GPL-2.0+) upstream releases.
