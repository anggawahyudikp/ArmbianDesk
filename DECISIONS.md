# Architectural Decisions (DECISIONS.md)

1. **Scope Expansion for Bootable Flashdisk Support**:
   - The base instruction kit scoped `armbiandesk` v0.1 as a post-boot desktop layer. Per owner direction (*"supaya user langsung bisa bikin bootable via flasdisk"*), a modular `bin/armbiandesk-image` (`tools/build-image.sh`, `tools/flash-usb.sh`) and optional `tools/b860h-usb-prep/` were added alongside the strict post-boot desktop layer.
   - **Boundary**: Proprietary/GPL kernel images and U-Boot binaries are **not** committed into git; `build-image.sh` consumes a user-supplied donor Armbian image or kernel/U-Boot archive at build time and compiles `s905_autoscript` / `aml_autoscript` cleanly from `.cmd` sources.
2. **Two Profiles (`minimal` Default, `desktop` Opt-In)**:
   - On ~915 MiB ARM64 STBs, `minimal` (`openbox` + static `feh` wallpaper + `xclock`) avoids resident panel/dock overhead. `desktop` (`xfwm4 --compositor=off` + `xfce4-panel` + one `plank` auto-hide dock) remains opt-in and falls back to `minimal` if `xfwm4` fails startup readiness.
3. **Conservative Sandboxed Browser Defaults**:
   - Chromium runs as a non-root user with sandbox and site isolation intact. Hardware video acceleration flags (`--disable-gpu`) are strictly opt-in via `BROWSER_COMPATIBILITY=software-rendering` rather than forced globally.
4. **Functional Panel Menu Over Decorative Labels**:
   - Replaced static decorative menu text with real XFCE `applicationsmenu` + `tasklist` + `clock` plugins.
5. **Neutral Original Assets**:
   - All visual assets (`share/wallpapers/armbiandesk.svg`, `share/plank/dock.theme`) are newly authored under MIT license with zero vendor/organization branding or startup audio.
6. **Untested / Host-Limited Boundaries**:
   - Live `debootstrap` ARM64 image build and real B860H cold-boot/USB-flash testing require host root + `debootstrap` + `u-boot-tools` + physical test STB hardware and are explicitly marked `NOT RUN` in `TEST_REPORT.md` / `BENCHMARK.md` when executed on a sandboxed build host.
