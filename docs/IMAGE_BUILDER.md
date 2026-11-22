# Bootable USB Flashdisk Image Builder

`armbiandesk-image` creates a complete bootable ARM64 `.img` from scratch (`debootstrap` userland + kernel/DTB/U-Boot bootchain + pre-installed ArmbianDesk) and writes it safely to a removable USB flashdisk.

## Host Prerequisites (x86_64 or ARM64 Linux Build Machine)
```bash
sudo apt-get update
sudo apt-get install -y debootstrap qemu-user-static parted dosfstools e2fsprogs u-boot-tools xz-utils
```

## Step 1: Prepare Donor Boot Assets
You need either:
- A donor Armbian/Amlogic `.img`/`.img.gz`/`.img.xz` (`--boot-source-image`, which supplies kernel `Image`, `/lib/modules`, `/boot/dtb`, and `u-boot.ext`), **or**
- `--kernel-tar` (tarball containing `Image`, optional `uInitrd`, `dtb/`, and `lib/modules/`) + `--uboot-dir` (directory containing `u-boot.ext`).

## Step 2: Dry-Run Build Plan
```bash
./bin/armbiandesk-image build \
  --distro debian --release bookworm \
  --profile minimal \
  --user deskuser \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --dtb amlogic/meson-gxl-s905x-p212.dtb \
  --cma-mb 64 \
  --output ./out/armbiandesk-usb.img \
  --dry-run
```
Optional flags: `--distro ubuntu --release noble`, `--profile desktop`, `--size-mb N`, `--boot-mb N`, `--hostname NAME`, `--start-url URL`, `--mirror URL` (run `./bin/armbiandesk-image build --help` for full usage).

## Step 3: Build the `.img` File
```bash
# Generate a SHA-512 password hash first (avoids cleartext passwords in shell history)
HASH="$(openssl passwd -6)"

sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm \
  --profile minimal \
  --user deskuser \
  --password-hash "$HASH" \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --dtb amlogic/meson-gxl-s905x-p212.dtb \
  --cma-mb 64 \
  --output ./out/armbiandesk-usb.img \
  --compress
```
If `--password-hash` is omitted, the image forces password creation on first login. Passing `--compress` also produces `.img.xz`.

## Step 4: Flash to USB Flashdisk Safely
Identify the whole USB disk device with `lsblk -d -o NAME,RM,TRAN,SIZE,MODEL` (for example `/dev/sdb`, never a partition such as `/dev/sdb1`), then dry-run and flash:
```bash
./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX --dry-run
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```
`armbiandesk-image flash` verifies `RM=1`, `TRAN=usb`, ensures no OS mountpoints exist on the disk, writes via `dd conv=fsync`, and verifies the exact written bytes using SHA-256 readback.

## Step 5: Boot on Target Device
- Insert the USB flash drive into the target box/SBC and trigger USB boot (e.g. reset/toothpick button or `reboot update` on supported Amlogic stock firmware).
- For stock ZTE B860H revisions whose U-Boot skips USB probing, read [HARDWARE.md](HARDWARE.md) and [../tools/b860h-usb-prep/README.md](../tools/b860h-usb-prep/README.md) first before modifying any U-Boot environment block.
