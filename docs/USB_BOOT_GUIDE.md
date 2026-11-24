# How to Make a TV Box (ZTE B860H / Amlogic) Detect & Boot the USB Flash Drive

Unlike a standard PC BIOS/UEFI, an Amlogic Android TV box does **not** always boot from USB automatically when plugged in. Whether it boots straight into ArmbianDesk or still boots Android depends on the U-Boot environment inside the box's internal eMMC.

Use the steps below in order — stop as soon as your box boots ArmbianDesk.

---

## Quick Checklist Before Troubleshooting

1. **Try every USB port on the TV box.** Stock Amlogic U-Boot (`usb start 0`) often probes **only USB port 0** (usually the port closest to the rear/corner of the board) and ignores the second port or external USB hubs.
2. **Verify the flash drive contents.** After flashing `.img.xz`, plugging the USB drive into a PC should show a FAT32 `ARMBIANBOOT` partition containing `Image`, `uInitrd`, `u-boot.ext`, `aml_autoscript`, `s905_autoscript`, `dtb/`, and `extlinux/`.
3. **Prefer a standard USB 2.0 / reliable USB 3.0 flash drive** plugged directly into the box (no unpowered USB hub).

---

## Method 1 — Already Unlocked / Previously Ran Armbian

If your TV box already booted Armbian or CoreELEC/LibreELEC from USB/SD before:
1. Power off the box, plug the ArmbianDesk USB drive into **USB port 0**.
2. Power on normally — stock/modified `bootcmd` should detect `s905_autoscript` / `u-boot.ext` automatically.

If it still boots into Android instead, move to **Method 2**.

---

## Method 2 — Reset Button ("Toothpick") or `adb reboot update`

On many stock B860H / Amlogic boxes, U-Boot only checks USB (`aml_autoscript`) when entering **update / recovery mode**:

### Option 2A: Reset / AV Pinhole Button (No PC Needed)
1. Unplug the power adapter from the TV box.
2. Plug the flashed ArmbianDesk USB drive into **USB port 0**.
3. Gently insert a toothpick / SIM ejector into the small **RESET / AV** pinhole and hold the internal button down.
4. While holding the button, plug in the power adapter, keep holding for **5–10 seconds**, then release.

### Option 2B: Trigger via ADB from Android
1. Power on stock Android on the TV box and enable **USB Debugging (ADB)** in *Settings → Developer options*.
2. Connect from your PC over LAN (`adb connect <BOX_IP>:5555`) or a USB-A-to-A cable (`adb devices`).
3. Plug the ArmbianDesk USB drive into **USB port 0**, then run:
   ```bash
   adb reboot update
   ```
   *(Some Android firmware builds also include an **Update & Backup** app where triggering an update reboots into USB detection.)*

> **Important Note on ArmbianDesk `v0.1.0`:** For safety, ArmbianDesk's default [`aml_autoscript.cmd`](../share/boot/aml_autoscript.cmd) does **not** automatically overwrite your eMMC (`saveenv`). If Method 2 boots only once or if your box's stock Android firmware skips USB completely during `normal` / `cold_boot`, continue to **Method 3**.

---

## Method 3 — Enable Persistent USB-First Boot on Locked ZTE B860H Boxes (ADB + Root)

> **WARNING — READ CAREFULLY:**
> This modifies the 64 KiB U-Boot environment partition (`/dev/block/env`). Hardware revisions branded as "ZTE B860H" (`v1`, `v2`, `v2.1`, `v5`) differ in SoC and bootloader layout. **Always keep an off-device backup of your original `b860h-env-backup.bin` and verify byte-for-byte readback (`cmp`) before rebooting.**

If Methods 1 and 2 keep booting straight into stock Android, `switch_bootmode` in `/dev/block/env` is likely skipping USB on `normal` / `cold_boot`. You can patch it safely using ArmbianDesk's helper:

### 1. Back up the original 64 KiB U-Boot env block to your PC
```bash
adb connect <BOX_IP>:5555
adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-backup.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-backup.bin"'
adb pull /data/local/tmp/b860h-env-backup.bin ./b860h-env-backup.bin
```
Keep `b860h-env-backup.bin` in a safe folder on your PC so you can restore the exact factory U-Boot environment anytime.

### 2. Inspect and patch locally (`dry-run` first)
Works on Linux, macOS, or Windows (requires Python 3):
```bash
# Dry-run: verifies CRC32 and shows Old -> New switch_bootmode without writing
python3 tools/b860h-usb-prep/b860h-usb-first-boot.py \
  --input ./b860h-env-backup.bin \
  --output ./b860h-env-patched.bin
```
If `CRC mismatch` or `switch_bootmode missing` appears, **stop** — your box uses a different U-Boot layout.

If the `Old:` and `New:` lines look valid, write the patched file:
```bash
python3 tools/b860h-usb-prep/b860h-usb-first-boot.py \
  --input ./b860h-env-backup.bin \
  --output ./b860h-env-patched.bin \
  --write
```

### 3. Write to `/dev/block/env` and verify byte-for-byte before rebooting
```bash
adb push ./b860h-env-patched.bin /data/local/tmp/b860h-env-patched.bin
adb shell 'su -c "dd if=/data/local/tmp/b860h-env-patched.bin of=/dev/block/env bs=65536 count=1; sync"'
adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-readback.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-readback.bin"'
adb pull /data/local/tmp/b860h-env-readback.bin ./b860h-env-readback.bin
cmp ./b860h-env-patched.bin ./b860h-env-readback.bin && echo "VERIFY OK — safe to reboot"
```
**Do not reboot if `cmp` fails.** Re-flash `./b860h-env-backup.bin` if anything looks wrong.

### 4. Reboot with the ArmbianDesk USB plugged into Port 0
```bash
adb reboot
```
From now on:
- **USB drive plugged in:** U-Boot runs `usb start 0` → `recovery_from_udisk` → boots **ArmbianDesk** from USB.
- **USB drive unplugged:** U-Boot falls back cleanly to **stock Android** on eMMC.
- **To undo completely:** Flash your saved `./b860h-env-backup.bin` back to `/dev/block/env` using the same `dd` + `cmp` steps.
