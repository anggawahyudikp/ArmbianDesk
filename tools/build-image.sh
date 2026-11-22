#!/usr/bin/env bash
set -euo pipefail

# ArmbianDesk Full Bootable Image Builder (ARM64 from scratch via debootstrap + donor/custom kernel+U-Boot).
# Builds a dual-partition raw .img (FAT32 boot + ext4 ROOTFS) with ArmbianDesk pre-installed.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: armbiandesk-image build [OPTIONS]

Required for real build (optional in --dry-run if testing layout only):
  --output PATH               Output .img path (e.g. ./out/armbiandesk-b860h.img)
  --boot-source-image PATH    Donor Armbian/Amlogic .img/.img.gz/.img.xz to extract kernel, modules, DTB, u-boot.ext
  OR
  --kernel-tar PATH           Tarball containing Image, uInitrd (optional), dtb/, and lib/modules/
  --uboot-dir PATH            Directory containing u-boot.ext (and optional boot scripts)

Options:
  --distro debian|ubuntu      Target userland distro (default: debian)
  --release CODENAME          Release codename (default: bookworm; e.g. trixie, noble)
  --mirror URL                APT mirror URL (default: http://deb.debian.org/debian or http://ports.ubuntu.com/ubuntu-ports)
  --profile minimal|desktop   Pre-installed ArmbianDesk profile (default: minimal)
  --user NAME                 Non-root desktop user to create (default: deskuser)
  --password-hash HASH        Pre-hashed password (from `openssl passwd -6`) for --user
  --hostname NAME             Image hostname (default: armbiandesk)
  --dtb RELPATH               DTB relative path under /boot/dtb (default: amlogic/meson-gxl-s905x-p212.dtb)
  --cma-mb N                  Kernel CMA size in MiB (default: 64)
  --size-mb N                 Total raw image size in MiB (default: 3584)
  --boot-mb N                 FAT32 boot partition size in MiB (default: 256)
  --start-url URL             Initial browser URL (default: https://example.org/)
  --compress                  Also create .img.xz after build
  --dry-run                   Validate inputs/dependencies and print exact build plan without writing disk/root ops
  -h, --help                  Show this help
EOF
}

DISTRO="debian"
RELEASE=""
MIRROR=""
PROFILE="minimal"
TARGET_USER="deskuser"
PASSWORD_HASH=""
HOSTNAME_VAL="armbiandesk"
DTB_RELPATH="amlogic/meson-gxl-s905x-p212.dtb"
CMA_MB="64"
SIZE_MB="3584"
BOOT_MB="256"
START_URL="https://example.org/"
BOOT_SOURCE_IMAGE=""
KERNEL_TAR=""
UBOOT_DIR=""
OUTPUT_IMG=""
COMPRESS_XZ=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --distro) DISTRO="${2:-}"; shift 2 ;;
        --release) RELEASE="${2:-}"; shift 2 ;;
        --mirror) MIRROR="${2:-}"; shift 2 ;;
        --profile) PROFILE="${2:-}"; shift 2 ;;
        --user) TARGET_USER="${2:-}"; shift 2 ;;
        --password-hash) PASSWORD_HASH="${2:-}"; shift 2 ;;
        --hostname) HOSTNAME_VAL="${2:-}"; shift 2 ;;
        --dtb) DTB_RELPATH="${2:-}"; shift 2 ;;
        --cma-mb) CMA_MB="${2:-}"; shift 2 ;;
        --size-mb) SIZE_MB="${2:-}"; shift 2 ;;
        --boot-mb) BOOT_MB="${2:-}"; shift 2 ;;
        --start-url) START_URL="${2:-}"; shift 2 ;;
        --boot-source-image) BOOT_SOURCE_IMAGE="${2:-}"; shift 2 ;;
        --kernel-tar) KERNEL_TAR="${2:-}"; shift 2 ;;
        --uboot-dir) UBOOT_DIR="${2:-}"; shift 2 ;;
        --output) OUTPUT_IMG="${2:-}"; shift 2 ;;
        --compress) COMPRESS_XZ=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$DISTRO" in
    debian)
        MIRROR="${MIRROR:-http://deb.debian.org/debian}"
        RELEASE="${RELEASE:-bookworm}"
        COMPONENTS="main,contrib,non-free-firmware"
        ;;
    ubuntu)
        MIRROR="${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"
        RELEASE="${RELEASE:-noble}"
        COMPONENTS="main,universe"
        ;;
    *)
        echo "error: --distro must be 'debian' or 'ubuntu'" >&2
        exit 2
        ;;
esac

case "$PROFILE" in
    minimal|desktop) ;;
    *) echo "error: --profile must be 'minimal' or 'desktop'" >&2; exit 2 ;;
esac

if ! printf '%s' "$TARGET_USER" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$' || [ "$TARGET_USER" = "root" ]; then
    echo "error: invalid non-root username '$TARGET_USER'" >&2
    exit 2
fi

if ! printf '%s' "$SIZE_MB" | grep -Eq '^[0-9]+$' || [ "$SIZE_MB" -lt 1536 ]; then
    echo "error: --size-mb must be an integer >= 1536" >&2
    exit 2
fi

if ! printf '%s' "$CMA_MB" | grep -Eq '^[0-9]+$' || [ "$CMA_MB" -lt 16 ] || [ "$CMA_MB" -gt 512 ]; then
    echo "error: --cma-mb must be between 16 and 512" >&2
    exit 2
fi

[ -n "$OUTPUT_IMG" ] || { echo "error: --output PATH is required" >&2; exit 2; }

if [ -z "$BOOT_SOURCE_IMAGE" ] && [ -z "$KERNEL_TAR" ]; then
    echo "error: provide either --boot-source-image PATH or --kernel-tar PATH + --uboot-dir PATH" >&2
    exit 2
fi
if [ -n "$BOOT_SOURCE_IMAGE" ] && [ ! -f "$BOOT_SOURCE_IMAGE" ]; then
    echo "error: --boot-source-image file not found: $BOOT_SOURCE_IMAGE" >&2
    exit 2
fi
if [ -n "$KERNEL_TAR" ] && [ ! -f "$KERNEL_TAR" ]; then
    echo "error: --kernel-tar file not found: $KERNEL_TAR" >&2
    exit 2
fi

PROFILE_PACKAGES=(
    systemd systemd-sysv udev dbus kmod iproute2 network-manager openssh-server
    sudo ca-certificates locales curl less nano
    xorg x11-xserver-utils x11-utils x11-apps lightdm lightdm-gtk-greeter
    feh wmctrl xdotool thunar gvfs chromium zram-tools earlyoom
)
if [ "$PROFILE" = "minimal" ]; then
    PROFILE_PACKAGES+=(openbox)
else
    PROFILE_PACKAGES+=(xfwm4 xfce4-panel plank libglib2.0-bin)
fi

REQUIRED_HOST_TOOLS=(debootstrap qemu-aarch64-static parted losetup mkfs.vfat mkfs.ext4 mkimage sha256sum)
MISSING_TOOLS=()
for tool in "${REQUIRED_HOST_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || MISSING_TOOLS+=("$tool")
done

echo "=== ArmbianDesk Bootable Image Build Plan ==="
echo "Output Image       : $OUTPUT_IMG (${SIZE_MB} MiB: ${BOOT_MB} MiB FAT32 ARMBIAN_BOOT + ext4 ARMBIAN_ROOT)"
echo "Base Userland      : $DISTRO $RELEASE (arm64 via debootstrap + qemu-aarch64-static)"
echo "APT Mirror         : $MIRROR ($COMPONENTS)"
echo "ArmbianDesk Profile: $PROFILE (user=$TARGET_USER, autologin=enabled)"
echo "DTB / Kernel Boot  : /dtb/$DTB_RELPATH (cma=${CMA_MB}M)"
if [ -n "$BOOT_SOURCE_IMAGE" ]; then
    echo "Boot/Kernel Donor  : $BOOT_SOURCE_IMAGE"
else
    echo "Kernel Tarball     : $KERNEL_TAR (U-Boot dir: ${UBOOT_DIR:-none})"
fi
echo "Packages (${#PROFILE_PACKAGES[@]})     : ${PROFILE_PACKAGES[*]}"
if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "Missing Host Tools : ${MISSING_TOOLS[*]} (install: sudo apt install debootstrap qemu-user-static parted dosfstools e2fsprogs u-boot-tools)"
else
    echo "Host Build Tools   : all required tools present"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Validation complete. No disk image created and no root/loopback commands run."
    exit 0
fi

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "error: real image build requires root (sudo) for debootstrap and loop mounts" >&2; exit 1; }
[ "${#MISSING_TOOLS[@]}" -eq 0 ] || { echo "error: missing required host tools: ${MISSING_TOOLS[*]}" >&2; exit 1; }

WORK_DIR="$(mktemp -d /tmp/armbiandesk-imgbuild.XXXXXX)"
LOOP_DEV=""
DONOR_LOOP=""
cleanup() {
    set +e
    for mp in "$WORK_DIR/mnt/boot" "$WORK_DIR/mnt/dev/pts" "$WORK_DIR/mnt/dev" "$WORK_DIR/mnt/proc" "$WORK_DIR/mnt/sys" "$WORK_DIR/mnt" "$WORK_DIR/donor_boot" "$WORK_DIR/donor_root"; do
        mountpoint -q "$mp" 2>/dev/null && umount -lf "$mp"
    done
    [ -n "$LOOP_DEV" ] && losetup -d "$LOOP_DEV" 2>/dev/null
    [ -n "$DONOR_LOOP" ] && losetup -d "$DONOR_LOOP" 2>/dev/null
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$(dirname "$OUTPUT_IMG")" "$WORK_DIR"/{mnt,donor_boot,donor_root,boot_assets}

# 1. Extract boot + kernel assets from donor image or tarball
if [ -n "$BOOT_SOURCE_IMAGE" ]; then
    DONOR_IMG="$BOOT_SOURCE_IMAGE"
    case "$BOOT_SOURCE_IMAGE" in
        *.xz)
            DONOR_IMG="$WORK_DIR/donor.img"
            xz -dc "$BOOT_SOURCE_IMAGE" >"$DONOR_IMG"
            ;;
        *.gz)
            DONOR_IMG="$WORK_DIR/donor.img"
            gzip -dc "$BOOT_SOURCE_IMAGE" >"$DONOR_IMG"
            ;;
    esac
    DONOR_LOOP="$(losetup --find --show -P --read-only "$DONOR_IMG")"
    mount -o ro "${DONOR_LOOP}p1" "$WORK_DIR/donor_boot"
    if [ -e "${DONOR_LOOP}p2" ]; then
        mount -o ro "${DONOR_LOOP}p2" "$WORK_DIR/donor_root"
        [ -d "$WORK_DIR/donor_root/lib/modules" ] && cp -a "$WORK_DIR/donor_root/lib/modules" "$WORK_DIR/modules"
        # Some Armbian images store /boot inside p2 if p1 isn't separate
        if [ ! -d "$WORK_DIR/donor_boot/dtb" ] && [ -d "$WORK_DIR/donor_root/boot" ]; then
            cp -a "$WORK_DIR/donor_root/boot/." "$WORK_DIR/boot_assets/"
        fi
    fi
    cp -a "$WORK_DIR/donor_boot/." "$WORK_DIR/boot_assets/"
else
    tar -xf "$KERNEL_TAR" -C "$WORK_DIR/boot_assets"
    if [ -d "$WORK_DIR/boot_assets/lib/modules" ]; then
        mv "$WORK_DIR/boot_assets/lib/modules" "$WORK_DIR/modules"
    fi
    if [ -n "$UBOOT_DIR" ] && [ -d "$UBOOT_DIR" ]; then
        cp -a "$UBOOT_DIR/." "$WORK_DIR/boot_assets/"
    fi
fi

# Verify essential kernel image & DTB
[ -f "$WORK_DIR/boot_assets/Image" ] || [ -f "$WORK_DIR/boot_assets/zImage" ] || { echo "error: kernel Image not found in boot assets" >&2; exit 1; }
[ -f "$WORK_DIR/boot_assets/dtb/$DTB_RELPATH" ] || { echo "error: DTB not found: $WORK_DIR/boot_assets/dtb/$DTB_RELPATH" >&2; exit 1; }

# 2. Allocate raw image & partition table (MBR: p1=FAT32 ARMBIAN_BOOT, p2=ext4 ARMBIAN_ROOT)
truncate -s "${SIZE_MB}M" "$OUTPUT_IMG"
parted -s "$OUTPUT_IMG" mklabel msdos
parted -s "$OUTPUT_IMG" mkpart primary fat32 4MiB "$((BOOT_MB + 4))MiB"
parted -s "$OUTPUT_IMG" set 1 boot on
parted -s "$OUTPUT_IMG" mkpart primary ext4 "$((BOOT_MB + 4))MiB" 100%

LOOP_DEV="$(losetup --find --show -P "$OUTPUT_IMG")"
mkfs.vfat -F 32 -n ARMBIAN_BOOT "${LOOP_DEV}p1"
mkfs.ext4 -F -L ARMBIAN_ROOT "${LOOP_DEV}p2"

mount "${LOOP_DEV}p2" "$WORK_DIR/mnt"
mkdir -p "$WORK_DIR/mnt/boot"
mount "${LOOP_DEV}p1" "$WORK_DIR/mnt/boot"

# 3. Debootstrap ARM64 userland via qemu-aarch64-static
debootstrap --arch=arm64 --foreign --components="$COMPONENTS" "$RELEASE" "$WORK_DIR/mnt" "$MIRROR"
cp /usr/bin/qemu-aarch64-static "$WORK_DIR/mnt/usr/bin/"
chroot "$WORK_DIR/mnt" /debootstrap/debootstrap --second-stage

# 4. Configure APT, base system, userland packages
mount --bind /dev "$WORK_DIR/mnt/dev"
mount --bind /dev/pts "$WORK_DIR/mnt/dev/pts"
mount -t proc proc "$WORK_DIR/mnt/proc"
mount -t sysfs sysfs "$WORK_DIR/mnt/sys"
[ -f /etc/resolv.conf ] && cp -L /etc/resolv.conf "$WORK_DIR/mnt/etc/resolv.conf"

printf '%s\n' "$HOSTNAME_VAL" >"$WORK_DIR/mnt/etc/hostname"
cat >"$WORK_DIR/mnt/etc/fstab" <<'EOF'
LABEL=ARMBIAN_ROOT  /      ext4  defaults,noatime,nodiratime,commit=60,errors=remount-ro  0  1
LABEL=ARMBIAN_BOOT  /boot  vfat  defaults,noatime                                          0  2
tmpfs               /tmp   tmpfs defaults,nosuid                                           0  0
EOF

chroot "$WORK_DIR/mnt" bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ${PROFILE_PACKAGES[*]}
apt-get clean
rm -rf /var/lib/apt/lists/*
"

# 5. Create non-root user (require explicit password hash or force password setup on first login)
chroot "$WORK_DIR/mnt" groupadd -f netdev
chroot "$WORK_DIR/mnt" useradd -m -s /bin/bash -G sudo,video,audio,netdev "$TARGET_USER"
if [ -n "$PASSWORD_HASH" ]; then
    printf '%s:%s\n' "$TARGET_USER" "$PASSWORD_HASH" | chroot "$WORK_DIR/mnt" chpasswd -e
else
    chroot "$WORK_DIR/mnt" passwd -d "$TARGET_USER"
    chroot "$WORK_DIR/mnt" chage -d 0 "$TARGET_USER"
fi

# 6. Install kernel, modules, DTB, U-Boot scripts, and extlinux.conf (FAT32-safe copy)
cp -r --no-preserve=ownership,mode "$WORK_DIR/boot_assets/." "$WORK_DIR/mnt/boot/"
if [ ! -f "$WORK_DIR/mnt/boot/Image" ]; then
    kfile="$(find "$WORK_DIR/mnt/boot" -maxdepth 1 -type f \( -name 'zImage' -o -name 'vmlinuz-*' -o -name 'Image-*' \) | head -n 1 || true)"
    [ -n "$kfile" ] && cp "$kfile" "$WORK_DIR/mnt/boot/Image"
fi
if [ ! -f "$WORK_DIR/mnt/boot/uInitrd" ]; then
    initrd_src="$(find "$WORK_DIR/mnt/boot" -maxdepth 1 -type f -name 'initrd.img-*' | head -n 1 || true)"
    if [ -n "$initrd_src" ]; then
        mkimage -A arm64 -O linux -T ramdisk -C none -d "$initrd_src" "$WORK_DIR/mnt/boot/uInitrd"
    fi
fi

if [ -d "$WORK_DIR/modules" ]; then
    mkdir -p "$WORK_DIR/mnt/lib/modules"
    cp -a "$WORK_DIR/modules/." "$WORK_DIR/mnt/lib/modules/"
fi

mkdir -p "$WORK_DIR/mnt/boot/extlinux"
sed -e "s|@DTB_RELPATH@|${DTB_RELPATH}|g" -e "s|@CMA_MB@|${CMA_MB}|g" \
    "$SELF_DIR/share/boot/extlinux.conf.in" >"$WORK_DIR/mnt/boot/extlinux/extlinux.conf"
if [ ! -f "$WORK_DIR/mnt/boot/uInitrd" ]; then
    sed -i '/^[[:space:]]*INITRD[[:space:]]/d' "$WORK_DIR/mnt/boot/extlinux/extlinux.conf"
fi

mkimage -C none -A arm -T script -d "$SELF_DIR/share/boot/s905_autoscript.cmd" "$WORK_DIR/mnt/boot/s905_autoscript"
mkimage -C none -A arm -T script -d "$SELF_DIR/share/boot/aml_autoscript.cmd" "$WORK_DIR/mnt/boot/aml_autoscript"

# 7. Configure zram & earlyoom safely for ~1GB RAM STBs
if [ -f "$WORK_DIR/mnt/etc/default/zramswap" ]; then
    sed -i 's/^#*\s*ALGO=.*/ALGO=lz4/' "$WORK_DIR/mnt/etc/default/zramswap"
    sed -i 's/^#*\s*PERCENT=.*/PERCENT=100/' "$WORK_DIR/mnt/etc/default/zramswap"
fi
cat >"$WORK_DIR/mnt/etc/default/earlyoom" <<'EOF'
EARLYOOM_ARGS="-m 10 -s 100 -r 30 --avoid '(^|/)(init|systemd|Xorg|sshd|openbox|xfwm4|lightdm|plank|xfce4-panel)$'"
EOF

# 8. Install ArmbianDesk directly into target image rootfs
"$SELF_DIR/bin/armbiandesk" install --root "$WORK_DIR/mnt" --user "$TARGET_USER" --profile "$PROFILE" --enable-autologin
python3 - "$WORK_DIR/mnt/etc/armbiandesk/armbiandesk.conf" "$START_URL" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
url = sys.argv[2]
lines = [
    f"START_URL={url}" if ln.startswith("START_URL=") else ln
    for ln in p.read_text(encoding="utf-8").splitlines()
]
p.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

# Clean up qemu binary before sealing image
rm -f "$WORK_DIR/mnt/usr/bin/qemu-aarch64-static"
sync

# Cleanup mounts before checksum
cleanup
trap - EXIT INT TERM

sha256sum "$OUTPUT_IMG" >"${OUTPUT_IMG}.sha256"
echo "Build complete: $OUTPUT_IMG"
cat "${OUTPUT_IMG}.sha256"

if [ "$COMPRESS_XZ" -eq 1 ]; then
    xz -T0 -k -f "$OUTPUT_IMG"
    sha256sum "${OUTPUT_IMG}.xz" >"${OUTPUT_IMG}.xz.sha256"
    echo "Compressed image: ${OUTPUT_IMG}.xz"
fi
