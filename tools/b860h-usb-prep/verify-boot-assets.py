#!/usr/bin/env python3
"""Verify U-Boot script (.scr) images against matching .cmd sources without executing them."""

from __future__ import annotations

import argparse
import pathlib
import struct
import sys
import zlib

UIMAGE_MAGIC = 0x27051956
UIMAGE_HEADER_SIZE = 64
UIMAGE_SCRIPT_TYPE = 6


class AssetError(ValueError):
    """Raised when a U-Boot script asset is malformed, stale, or corrupt."""


def crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


def verify_uimage(path: pathlib.Path) -> bytes:
    raw = path.read_bytes()
    if len(raw) < UIMAGE_HEADER_SIZE:
        raise AssetError(f"{path}: shorter than a 64-byte U-Boot image header")

    header = bytearray(raw[:UIMAGE_HEADER_SIZE])
    magic, stored_header_crc, _, data_size, _, _, stored_data_crc = struct.unpack(">7I", header[:28])
    image_type = header[30]
    if magic != UIMAGE_MAGIC:
        raise AssetError(f"{path}: bad U-Boot magic 0x{magic:08x}")
    if image_type != UIMAGE_SCRIPT_TYPE:
        raise AssetError(f"{path}: expected script type 6, got {image_type}")

    header[4:8] = b"\0\0\0\0"
    actual_header_crc = crc32(header)
    if stored_header_crc != actual_header_crc:
        raise AssetError(f"{path}: header CRC mismatch stored={stored_header_crc:08x} actual={actual_header_crc:08x}")

    payload = raw[UIMAGE_HEADER_SIZE : UIMAGE_HEADER_SIZE + data_size]
    if len(payload) != data_size:
        raise AssetError(f"{path}: truncated payload expected={data_size} actual={len(payload)}")
    actual_data_crc = crc32(payload)
    if stored_data_crc != actual_data_crc:
        raise AssetError(f"{path}: data CRC mismatch stored={stored_data_crc:08x} actual={actual_data_crc:08x}")
    return payload


def script_source(payload: bytes, path: pathlib.Path) -> bytes:
    if len(payload) < 8:
        raise AssetError(f"{path}: script payload missing size table")
    declared_size, terminator = struct.unpack(">2I", payload[:8])
    if declared_size != len(payload) - 8 or terminator != 0:
        raise AssetError(f"{path}: malformed script size table")
    return payload[8:]


def verify_directory(scripts_dir: pathlib.Path) -> tuple[int, int]:
    images = sorted(scripts_dir.glob("*.scr"))
    if not images:
        raise AssetError(f"{scripts_dir}: no .scr boot assets found")

    paired = 0
    for image in images:
        source = image.with_suffix(".cmd")
        if not source.exists():
            raise AssetError(f"{image}: matching {source.name} source is missing")
        embedded = script_source(verify_uimage(image), image)
        if embedded != source.read_bytes():
            raise AssetError(f"{image}: embedded script differs from {source.name}")
        paired += 1
    return len(images), paired


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify U-Boot .scr/.cmd pairs.")
    parser.add_argument("scripts_dir", nargs="?", type=pathlib.Path, default=pathlib.Path("."))
    args = parser.parse_args()
    try:
        images, paired = verify_directory(args.scripts_dir)
    except (AssetError, OSError) as exc:
        print(f"Boot asset verification failed: {exc}", file=sys.stderr)
        return 1
    print(f"Boot assets OK: images={images} source_pairs={paired}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
