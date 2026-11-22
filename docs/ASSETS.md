# Assets & Provenance

All graphical/config assets bundled in ArmbianDesk are newly created, neutral, and licensed under MIT:

| Asset Path | Origin | License | Purpose |
|---|---|---|---|
| `share/wallpapers/armbiandesk.svg` | Original authored SVG | MIT | Neutral static desktop wallpaper |
| `share/plank/dock.theme` | Original INI configuration | MIT | Neutral slate Plank dock theme (no shadows/glow) |
| `share/openbox/rc.xml`, `menu.xml` | Original authored XML | MIT | Minimal profile window management & menu |
| `share/xfce4/xfce4-panel.xml`, `xfwm4.xml` | Original authored XML | MIT | Desktop profile top panel & WM settings |
| `share/boot/*.cmd`, `extlinux.conf.in` | Original authored boot templates | MIT | Parameterized Amlogic U-Boot/extlinux templates |

Icons referenced by `.desktop` files (`web-browser`, `system-file-manager`) resolve dynamically from the distribution's installed icon theme.
