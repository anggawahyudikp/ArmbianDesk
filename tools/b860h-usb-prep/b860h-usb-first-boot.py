#!/usr/bin/env python3
"""Patch a local ZTE B860H 64 KiB U-Boot env dump so normal/cold boots try USB first.

EXPERIMENTAL / OPTIONAL TOOL:
This operates ONLY on a local backup env dump file. It never connects to an STB
and never writes eMMC directly. Hardware revisions differ across B860H units;
always back up the original eMMC env partition and verify readback before rebooting.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import zlib
from pathlib import Path

ENV_SIZE = 0x10000

USB_FIRST_SWITCH_BOOTMODE = (
    "switch_bootmode=get_rebootmode;"
    "if test ${reboot_mode} = factory_reset; then run recovery_from_flash;"
    "else if test ${reboot_mode} = update; then run update;"
    "else if test ${reboot_mode} = cold_boot; then if usb start 0; then run recovery_from_udisk; fi;"
    "else if test ${reboot_mode} = normal; then if usb start 0; then run recovery_from_udisk; fi;"
    "fi;fi;fi;fi;"
)


class EnvError(RuntimeError):
    pass


def load_env_block(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) < ENV_SIZE:
        raise EnvError(f"{path} is too small: {len(data)} bytes, need at least {ENV_SIZE}")
    return data[:ENV_SIZE]


def validate_crc(block: bytes) -> tuple[int, int]:
    stored = struct.unpack("<I", block[:4])[0]
    computed = zlib.crc32(block[4:]) & 0xFFFFFFFF
    if stored != computed:
        raise EnvError(
            f"CRC mismatch: stored={stored:#x}, computed={computed:#x}. "
            "Refusing to patch an unrecognized env block."
        )
    return stored, computed


def parse_entries(block: bytes) -> list[str]:
    payload = block[4:]
    end = payload.find(b"\0\0")
    if end < 0:
        raise EnvError("double-NUL terminator not found")

    entries: list[str] = []
    for item in payload[:end].split(b"\0"):
        if not item:
            continue
        try:
            entries.append(item.decode("utf-8"))
        except UnicodeDecodeError as exc:
            raise EnvError(f"env contains non-UTF8 entry: {item!r}") from exc
    return entries


def build_block(entries: list[str]) -> bytes:
    payload = "\0".join(entries).encode("utf-8") + b"\0\0"
    if len(payload) > ENV_SIZE - 4:
        raise EnvError(f"patched env too large: {len(payload) + 4} bytes")

    block = bytearray(ENV_SIZE)
    block[4 : 4 + len(payload)] = payload
    crc = zlib.crc32(block[4:]) & 0xFFFFFFFF
    block[:4] = struct.pack("<I", crc)
    return bytes(block)


def patch_entries(entries: list[str]) -> tuple[list[str], str]:
    if not any(item.startswith("recovery_from_udisk=") for item in entries):
        raise EnvError("recovery_from_udisk missing; this does not look like a supported B860H U-Boot env")

    old_switch = None
    patched: list[str] = []
    for item in entries:
        if item.startswith("switch_bootmode="):
            old_switch = item
            patched.append(USB_FIRST_SWITCH_BOOTMODE)
        else:
            patched.append(item)

    if old_switch is None:
        raise EnvError("switch_bootmode missing; refusing to invent boot policy")

    return patched, old_switch


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch a local 64 KiB B860H U-Boot env dump to try USB boot first (with Android fallback)."
    )
    parser.add_argument("--input", required=True, type=Path, help="Input 64 KiB env dump file")
    parser.add_argument("--output", required=True, type=Path, help="Patched 64 KiB output file")
    parser.add_argument("--write", action="store_true", help="Write the patched output file (default is dry-run)")
    args = parser.parse_args()

    try:
        block = load_env_block(args.input)
        validate_crc(block)
        entries = parse_entries(block)
        patched_entries, old_switch = patch_entries(entries)
        patched_block = build_block(patched_entries)
        validate_crc(patched_block)
    except (EnvError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print("Input :", args.input)
    print("Output:", args.output)
    print("Old   :", old_switch)
    print("New   :", USB_FIRST_SWITCH_BOOTMODE)
    print("SHA256:", hashlib.sha256(patched_block).hexdigest())

    if args.write:
        args.output.write_bytes(patched_block)
        print("Wrote patched env block.")
    else:
        print("Dry run only. Pass --write to generate the patched env block.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
