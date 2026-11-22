# Optional B860H USB-First-Boot Prep (Experimental)

> **WARNING — READ BEFORE USING:**
> Modifying `/dev/block/env` on an Amlogic STB carries **bricking risk** if your board revision uses a different environment partition offset, size, or U-Boot layout.
> Hardware revisions branded as "ZTE B860H" (v1, v2, v2.1, v5) differ in SoC, Wi-Fi chip, DTB, and stock bootloader policies.

## When Is This Needed?
Some stock Android firmware builds on B860H only check USB boot (`aml_autoscript`) when entering recovery/update mode, or have `switch_bootmode` configured to boot Android eMMC directly without probing USB.

If your box already boots USB flashdisks directly (via toothpick/reset button, `reboot update`, or prior unlock), **do not touch `/dev/block/env`**.

## Safe Local Patching Workflow (Dry-Run First)
1. Back up the original 64 KiB U-Boot environment block from Android/STB to your host machine and keep a copy safe off-device.
2. Inspect and dry-run the patcher locally:
   ```bash
   ./bin/armbiandesk-image b860h-prep --input ./b860h-env-backup.bin --output ./b860h-env-usb-first.bin
   ```
3. Review `Old:` and `New:` `switch_bootmode` values and verify CRC/SHA-256, then pass `--write`:
   ```bash
   ./bin/armbiandesk-image b860h-prep --input ./b860h-env-backup.bin --output ./b860h-env-usb-first.bin --write
   ```
4. If you choose to flash the patched env block onto an authorized test device (e.g. via `adb`), always read back the written block (`dd if=/dev/block/env ...`) and verify byte-for-byte with `cmp` before rebooting.
