# Installing ArmbianDesk (Post-Boot Armbian System)

## Prerequisites
Install required packages from your configured Debian/Ubuntu/Armbian APT repositories:
```bash
sudo apt-get update
# Minimal profile dependencies:
sudo apt-get install -y xorg x11-xserver-utils x11-utils x11-apps openbox feh wmctrl xdotool thunar chromium

# Optional Desktop profile additions:
sudo apt-get install -y xfwm4 xfce4-panel plank libglib2.0-bin

# Recommended low-RAM helpers:
sudo apt-get install -y zram-tools earlyoom
```
> **Note on Ubuntu ARM64:** Check `apt-cache policy chromium` to verify whether `chromium` is a native `.deb` or a transitional Snap wrapper. ArmbianDesk targets native `.deb` Chromium where available.

## Install Steps
1. Preview installation plan without modifying files:
   ```bash
   ./bin/armbiandesk install --user USER --profile minimal --dry-run
   ```
2. Install ArmbianDesk:
   ```bash
   sudo ./bin/armbiandesk install --user USER --profile minimal
   ```
   This registers `/usr/share/xsessions/armbiandesk.desktop` in LightDM without changing your active session or enabling autologin.
3. Optional: Enable LightDM autologin via an isolated drop-in (`/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf`):
   ```bash
   sudo ./bin/armbiandesk install --user USER --profile minimal --enable-autologin
   ```
4. Switch profiles at any time (effective on next login):
   ```bash
   sudo armbiandesk profile set desktop
   ```
