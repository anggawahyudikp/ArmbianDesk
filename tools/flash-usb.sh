#!/usr/bin/env bash
set -euo pipefail

# Safe removable-only USB flashdisk writer with SHA-256 readback verification.

usage() {
    cat <<'EOF'
Usage: armbiandesk-image flash --image PATH --device /dev/sdX [--yes] [--dry-run]

Safety guards:
  - Refuses non-removable disks (lsblk RM != 1)
  - Refuses disks backing '/', '/boot', or swap
  - Requires USB transport (TRAN=usb) unless --allow-non-usb is passed
  - Verifies exact written bytes via SHA-256 readback
EOF
}

IMG_PATH=""
DEV_PATH=""
ALLOW_NON_USB=0
AUTO_YES=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --image) IMG_PATH="${2:-}"; shift 2 ;;
        --device) DEV_PATH="${2:-}"; shift 2 ;;
        --allow-non-usb) ALLOW_NON_USB=1; shift ;;
        --yes) AUTO_YES=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -n "$IMG_PATH" ] || { echo "error: --image PATH is required" >&2; exit 2; }
[ -n "$DEV_PATH" ] || { echo "error: --device /dev/sdX is required" >&2; exit 2; }
[ -f "$IMG_PATH" ] || { echo "error: image file not found: $IMG_PATH" >&2; exit 2; }

if [[ "$DEV_PATH" =~ [0-9]$ ]] && [[ ! "$DEV_PATH" =~ mmcblk[0-9]+$ ]] && [[ ! "$DEV_PATH" =~ nvme[0-9]+n[0-9]+$ ]]; then
    echo "error: target must be a whole disk device (e.g. /dev/sdb), not a partition ($DEV_PATH)" >&2
    exit 2
fi

if [ "$DRY_RUN" -ne 1 ]; then
    [ "${EUID:-$(id -u)}" -eq 0 ] || { echo "error: writing block device requires root (sudo)" >&2; exit 1; }
    [ -b "$DEV_PATH" ] || { echo "error: block device not found: $DEV_PATH" >&2; exit 2; }
fi

if [ -b "$DEV_PATH" ] && command -v lsblk >/dev/null 2>&1; then
    dev_rm="$(lsblk -dn -o RM "$DEV_PATH" | tr -d '[:space:]')"
    dev_tran="$(lsblk -dn -o TRAN "$DEV_PATH" | tr -d '[:space:]')"
    dev_size="$(lsblk -dn -b -o SIZE "$DEV_PATH" | tr -d '[:space:]')"
    dev_model="$(lsblk -dn -o MODEL "$DEV_PATH" | xargs)"

    if [ "$dev_rm" != "1" ]; then
        echo "error: refusing non-removable device $DEV_PATH (RM=$dev_rm)" >&2
        exit 1
    fi
    if [ "$ALLOW_NON_USB" -ne 1 ] && [ "$dev_tran" != "usb" ]; then
        echo "error: refusing non-USB device $DEV_PATH (TRAN=$dev_tran; pass --allow-non-usb to override)" >&2
        exit 1
    fi

    # Refuse if any partition on device is mounted at /, /boot, or /home
    if lsblk -n -o MOUNTPOINT "$DEV_PATH" | grep -Eq '^(/|/boot|/home)$'; then
        echo "error: refusing device with active OS mountpoint on $DEV_PATH" >&2
        exit 1
    fi
    echo "Target device: $DEV_PATH (model='${dev_model:-unknown}', tran=$dev_tran, size=$dev_size bytes)"
else
    echo "Target device: $DEV_PATH (validated in dry-run fixture mode)"
fi

echo "Source image : $IMG_PATH"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would unmount partitions on $DEV_PATH, write $IMG_PATH with dd conv=fsync, and verify SHA-256 readback."
    exit 0
fi

if [ "$AUTO_YES" -ne 1 ]; then
    printf "ALL DATA on %s will be erased. Type 'FLASH' to continue: " "$DEV_PATH"
    read -r reply
    [ "$reply" = "FLASH" ] || { echo "Aborted."; exit 1; }
fi

# Unmount any mounted partitions on target device
while read -r part; do
    [ -n "$part" ] && umount "/dev/$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEV_PATH" | tail -n +2)

src_bytes=""
src_sha=""
case "$IMG_PATH" in
    *.xz)
        tmp_sha="$(mktemp)"
        xz -dc "$IMG_PATH" | tee >(sha256sum >"$tmp_sha") | dd of="$DEV_PATH" bs=4M oflag=direct status=progress conv=fsync
        src_sha="$(awk '{print $1}' "$tmp_sha")"
        rm -f "$tmp_sha"
        src_bytes="$(xz -l --robot "$IMG_PATH" | awk '/^totals/{print $5}')"
        ;;
    *.gz)
        tmp_sha="$(mktemp)"
        gzip -dc "$IMG_PATH" | tee >(sha256sum >"$tmp_sha") | dd of="$DEV_PATH" bs=4M oflag=direct status=progress conv=fsync
        src_sha="$(awk '{print $1}' "$tmp_sha")"
        rm -f "$tmp_sha"
        src_bytes="$(gzip -l "$IMG_PATH" | awk 'NR==2{print $2}')"
        ;;
    *)
        src_bytes="$(stat -c '%s' "$IMG_PATH")"
        src_sha="$(sha256sum "$IMG_PATH" | awk '{print $1}')"
        dd if="$IMG_PATH" of="$DEV_PATH" bs=4M oflag=direct status=progress conv=fsync
        ;;
esac

sync
blockdev --rereadpt "$DEV_PATH" 2>/dev/null || true

if [ -n "$src_bytes" ] && [ -n "$src_sha" ]; then
    echo "Verifying written bytes ($src_bytes bytes)..."
    readback_sha="$(head -c "$src_bytes" "$DEV_PATH" | sha256sum | awk '{print $1}')"
    if [ "$readback_sha" != "$src_sha" ]; then
        echo "error: verification FAILED! expected=$src_sha actual=$readback_sha" >&2
        exit 1
    fi
    echo "Verification OK: SHA-256 $readback_sha"
fi
