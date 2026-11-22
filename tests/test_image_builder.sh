#!/usr/bin/env bash
set -euo pipefail

# Image builder dry-run, USB flash safety guard, B860H env CRC32 patcher, and uImage boot asset tests.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_BIN="$ROOT_DIR/bin/armbiandesk-image"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[IMG-01] Testing armbiandesk-image build --dry-run and argument validation..."
touch "$TMP_DIR/donor.img"
"$IMG_BIN" build \
    --distro debian --release bookworm \
    --profile minimal --user deskuser \
    --boot-source-image "$TMP_DIR/donor.img" \
    --output "$TMP_DIR/out.img" \
    --dry-run >/dev/null

# Reject root username and undersized image
! "$IMG_BIN" build --user root --boot-source-image "$TMP_DIR/donor.img" --output "$TMP_DIR/out.img" --dry-run >/dev/null 2>&1 || {
    echo "FAIL: accepted root user in image builder" >&2; exit 1;
}
! "$IMG_BIN" build --size-mb 512 --boot-source-image "$TMP_DIR/donor.img" --output "$TMP_DIR/out.img" --dry-run >/dev/null 2>&1 || {
    echo "FAIL: accepted undersized image (<1536 MiB)" >&2; exit 1;
}

echo "[IMG-02] Testing armbiandesk-image flash --dry-run and partition guard..."
"$IMG_BIN" flash --image "$TMP_DIR/donor.img" --device /dev/sdz --dry-run >/dev/null
! "$IMG_BIN" flash --image "$TMP_DIR/donor.img" --device /dev/sdb1 --dry-run >/dev/null 2>&1 || {
    echo "FAIL: accepted partition path /dev/sdb1 instead of whole disk" >&2; exit 1;
}

echo "[IMG-03] Testing B860H U-Boot env USB-first patcher (CRC32 + dry-run + write)..."
python3 - "$TMP_DIR" "$IMG_BIN" <<'PY'
import pathlib, struct, subprocess, sys, zlib

tmp = pathlib.Path(sys.argv[1])
img_bin = sys.argv[2]

entries = [
    "bootcmd=run storeboot",
    "recovery_from_udisk=if fatload usb 0 1020000 aml_autoscript; then autoscr 1020000; fi",
    "switch_bootmode=get_rebootmode;if test ${reboot_mode} = normal; then echo normal; fi",
]
payload = ("\0".join(entries)).encode("utf-8") + b"\0\0"
block = bytearray(0x10000)
block[4 : 4 + len(payload)] = payload
crc = zlib.crc32(block[4:]) & 0xFFFFFFFF
block[:4] = struct.pack("<I", crc)

in_env = tmp / "env.bin"
out_env = tmp / "env-patched.bin"
in_env.write_bytes(bytes(block))

# Dry-run must not write output file
r_dry = subprocess.run([img_bin, "b860h-prep", "--input", str(in_env), "--output", str(out_env)], capture_output=True, text=True)
assert r_dry.returncode == 0, r_dry.stderr
assert not out_env.exists(), "Dry-run created output file!"

# --write creates valid CRC32 patched block
r_wr = subprocess.run([img_bin, "b860h-prep", "--input", str(in_env), "--output", str(out_env), "--write"], capture_output=True, text=True)
assert r_wr.returncode == 0, r_wr.stderr
patched = out_env.read_bytes()
assert len(patched) == 0x10000
assert struct.unpack("<I", patched[:4])[0] == (zlib.crc32(patched[4:]) & 0xFFFFFFFF)
assert b"recovery_from_udisk" in patched

# Corrupt CRC must be rejected
bad_env = tmp / "bad-env.bin"
bad = bytearray(block)
bad[10] ^= 0xFF
bad_env.write_bytes(bytes(bad))
r_bad = subprocess.run([img_bin, "b860h-prep", "--input", str(bad_env), "--output", str(out_env)], capture_output=True, text=True)
assert r_bad.returncode != 0, "Corrupt CRC env was accepted!"
PY

echo "[IMG-04] Testing verify-boot U-Boot .scr/.cmd verification..."
python3 - "$TMP_DIR" "$ROOT_DIR/share/boot/s905_autoscript.cmd" "$IMG_BIN" <<'PY'
import pathlib, shutil, struct, subprocess, sys, zlib

tmp = pathlib.Path(sys.argv[1])
src_cmd = pathlib.Path(sys.argv[2])
img_bin = sys.argv[3]

boot_test = tmp / "boot_verify"
boot_test.mkdir()
cmd_copy = boot_test / "s905_autoscript.cmd"
cmd_bytes = src_cmd.read_bytes()
cmd_copy.write_bytes(cmd_bytes)

# Construct valid 64-byte U-Boot script uImage matching mkimage format
payload = struct.pack(">2I", len(cmd_bytes), 0) + cmd_bytes
data_crc = zlib.crc32(payload) & 0xFFFFFFFF
header = bytearray(64)
struct.pack_into(">7I", header, 0, 0x27051956, 0, 0, len(payload), 0, 0, data_crc)
header[28:32] = bytes([5, 2, 6, 0])  # OS=Linux(5), Arch=ARM(2), Type=Script(6), Comp=None(0)
header_crc = zlib.crc32(header) & 0xFFFFFFFF
struct.pack_into(">I", header, 4, header_crc)

(boot_test / "s905_autoscript.scr").write_bytes(bytes(header) + payload)
res = subprocess.run([img_bin, "verify-boot", str(boot_test)], capture_output=True, text=True)
assert res.returncode == 0, res.stderr
PY

echo "PASS: Image builder dry-run, USB flasher guard, B860H env patcher, and boot verifier passed."
