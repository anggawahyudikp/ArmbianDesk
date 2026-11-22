# Troubleshooting

## Browser Window Does Not Reopen After Closing
This is **intended behavior**. Normal user exit (`exit code 0`) does not trigger an automatic respawn loop. Reopen Chromium from the `ArmbianDesk Browser` launcher, desktop right-click menu (`Minimal`), dock, or run `armbiandesk browser`.

## Desktop Profile Falls Back to Minimal
If `xfwm4` is missing or fails to become ready within 10 seconds, `armbiandesk session` logs a warning, cleans up failed child processes, and falls back to `openbox` (`minimal` profile). Install `xfwm4 xfce4-panel plank` to use the `desktop` profile.

## Config Validation Errors (`armbiandesk config validate`)
- Ensure `START_URL` is either empty or starts with `http://` / `https://` with no unencoded spaces or shell markers (`$(...)`, `` ` ``).
- Ensure there are no duplicate keys, unknown keys, or symlinked config files.

## USB Flashdisk Does Not Boot on Stock Android B860H
Some stock B860H units require triggering recovery/update mode (e.g. reset pinhole or `adb reboot update`) or enabling USB-first-boot in U-Boot env. See [tools/b860h-usb-prep/README.md](../tools/b860h-usb-prep/README.md) for the optional local env patcher and hardware risk notes.
