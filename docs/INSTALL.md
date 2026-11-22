# Installing ArmbianDesk (Post-Boot Armbian System)

## 1. Prerequisites
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

## 2. Download or Clone ArmbianDesk
```bash
git clone https://github.com/anggawahyudikp/ArmbianDesk.git
cd ArmbianDesk
```

## 3. Install Steps
1. Preview installation plan without modifying files (`USER` must be an existing non-root desktop user):
   ```bash
   ./bin/armbiandesk install --user USER --profile minimal --dry-run
   ```
2. Install ArmbianDesk:
   ```bash
   sudo ./bin/armbiandesk install --user USER --profile minimal
   ```
   This installs:
   - CLI & runtime libraries: `/usr/local/bin/armbiandesk` and `/usr/local/share/armbiandesk/`
   - Configuration file: `/etc/armbiandesk/armbiandesk.conf`
   - LightDM session entry: `/usr/share/xsessions/armbiandesk.desktop`
   - User Openbox/XFCE/Plank configs under `~USER/.config/` and `~USER/.local/share/plank/`
   - Atomic backup manifest under `/var/lib/armbiandesk/backups/<BACKUP_ID>`

   Save the printed **`Backup ID`** in case you ever want to restore pre-install files.
3. Optional: Enable LightDM autologin via an isolated drop-in (`/etc/lightdm/lightdm.conf.d/50-armbiandesk-autologin.conf`):
   ```bash
   sudo ./bin/armbiandesk install --user USER --profile minimal --enable-autologin
   ```

## 4. Configure, Switch Profiles & Verify
1. Edit `/etc/armbiandesk/armbiandesk.conf` (see [`config/armbiandesk.conf.example`](../config/armbiandesk.conf.example) for allowed keys like `START_URL`, `LANGUAGE`, `DISPLAY_MODE`, `BROWSER_COMPATIBILITY`) and validate it before rebooting:
   ```bash
   sudo armbiandesk config validate --file /etc/armbiandesk/armbiandesk.conf
   ```
2. Switch profiles at any time (effective on next login):
   ```bash
   sudo armbiandesk profile set desktop
   ```
3. Check active configuration and status:
   ```bash
   armbiandesk status --json
   ```
4. Uninstall or restore pre-install backups cleanly — see [UNINSTALL.md](UNINSTALL.md).
