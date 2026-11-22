# Bootable USB Flashdisk Image Builder

`armbiandesk-image` creates a complete bootable ARM64 `.img` from scratch (`debootstrap` userland + kernel/DTB/U-Boot bootchain + pre-installed ArmbianDesk) and writes it safely to a removable USB flashdisk.

## Host Prerequisites (x86_64 or ARM64 Linux Build Machine)
```bash
sudo apt-get update
sudo apt-get install -y debootstrap qemu-user-static parted dosfstools e2fsprogs u-boot-tools xz-utils
```

## Step 1: Dry-Run Build Plan
You need either a donor Armbian/Amlogic `.img`/`.img.xz`/`.img.gz` (for kernel `Image`, `/lib/modules`, `/boot/dtb`, and `u-boot.ext`) **or** `--kernel-tar` + `--uboot-dir`:
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

## Step 2: Build the `.img` File
```bash
# Generate a password hash first (avoid cleartext passwords in shell history)
HASH="$(openssl passwd -6)"

sudo ./bin/armbiandesk-image build \
  --distro debian --release bookworm \
  --profile minimal \
  --user deskuser \
  --password-hash "$HASH" \
  --boot-source-image /path/to/official-armbian-s905x.img \
  --output ./out/armbiandesk-usb.img \
  --compress
```
If `--password-hash` is omitted, the image forces password creation on first login.

## Step 3: Flash to USB Flashdisk Safely
Identify your USB device with `lsblk -d -o NAME,RM,TRAN,SIZE,MODEL`, then dry-run and flash:
```bash
./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX --dry-run
sudo ./bin/armbiandesk-image flash --image ./out/armbiandesk-usb.img --device /dev/sdX
```
`armbiandesk-image flash` verifies `RM=1`, `TRAN=usb`, ensures no OS mountpoints exist on the disk, writes via `dd conv=fsync`, and verifies the exact written bytes using SHA-256 readback.
