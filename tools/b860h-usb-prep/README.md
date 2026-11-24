# Optional B860H USB-First-Boot Prep (Experimental)

> **WARNING — READ BEFORE USING:**
> Modifying `/dev/block/env` on an Amlogic STB carries **bricking risk** if your board revision uses a different environment partition offset, size, or U-Boot layout.
> Hardware revisions branded as "ZTE B860H" (v1, v2, v2.1, v5) differ in SoC, Wi-Fi chip, DTB, and stock bootloader policies.

## When Is This Needed?
Some stock Android firmware builds on B860H only check USB boot (`aml_autoscript`) when entering recovery/update mode, or have `switch_bootmode` configured to boot Android eMMC directly without probing USB.

If your box already boots USB flashdisks directly (via toothpick/reset button, `reboot update`, or prior unlock), **do not touch `/dev/block/env`**.

## Full Step-by-Step Guide
See [docs/USB_BOOT_GUIDE.md](../../docs/USB_BOOT_GUIDE.md) ([Bahasa Indonesia](../../docs/USB_BOOT_GUIDE.id.md)) for trying Reset/Toothpick, `adb reboot update`, and the complete ADB backup + readback `cmp` procedure.

## Safe Local Patching Workflow (Dry-Run First)
1. Back up the original 64 KiB U-Boot environment block from Android/STB to your host machine and keep a copy safe off-device:
   ```bash
   adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-backup.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-backup.bin"'
   adb pull /data/local/tmp/b860h-env-backup.bin ./b860h-env-backup.bin
   ```
2. Inspect and dry-run the patcher locally (`armbiandesk-image b860h-prep` or `python3` on Windows/macOS/Linux):
   ```bash
   python3 tools/b860h-usb-prep/b860h-usb-first-boot.py --input ./b860h-env-backup.bin --output ./b860h-env-usb-first.bin
   ```
3. Review `Old:` and `New:` `switch_bootmode` values and verify CRC/SHA-256, then pass `--write`:
   ```bash
   python3 tools/b860h-usb-prep/b860h-usb-first-boot.py --input ./b860h-env-backup.bin --output ./b860h-env-usb-first.bin --write
   ```
4. If you choose to flash the patched env block onto an authorized test device via `adb`, always read back the written block and verify byte-for-byte with `cmp` before rebooting:
   ```bash
   adb push ./b860h-env-usb-first.bin /data/local/tmp/b860h-env-usb-first.bin
   adb shell 'su -c "dd if=/data/local/tmp/b860h-env-usb-first.bin of=/dev/block/env bs=65536 count=1; sync"'
   adb shell 'su -c "dd if=/dev/block/env of=/data/local/tmp/b860h-env-readback.bin bs=65536 count=1; chmod 644 /data/local/tmp/b860h-env-readback.bin"'
   adb pull /data/local/tmp/b860h-env-readback.bin ./b860h-env-readback.bin
   cmp ./b860h-env-usb-first.bin ./b860h-env-readback.bin
   ```
