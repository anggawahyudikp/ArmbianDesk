#!/usr/bin/env python3
"""T02 — Config parser safety and anti-injection test suite."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
BIN = str(ROOT_DIR / "bin" / "armbiandesk")


def run_validate(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [BIN, "config", "validate", "--file", str(path)],
        text=True,
        capture_output=True,
        check=False,
    )


def assert_valid(name: str, content: str) -> None:
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / f"{name}.conf"
        p.write_text(content, encoding="utf-8")
        res = run_validate(p)
        assert res.returncode == 0, f"Expected valid for {name}, got rc={res.returncode}: {res.stderr}"


def assert_invalid(name: str, raw_bytes: bytes) -> None:
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / f"{name}.conf"
        p.write_bytes(raw_bytes)
        res = run_validate(p)
        assert res.returncode != 0, f"Expected rejection for {name}, got rc=0!"


def main() -> int:
    # 1. Valid configurations
    assert_valid("minimal_default", "PROFILE=minimal\nSTART_URL=https://example.org/\n")
    assert_valid("desktop_profile", "PROFILE=desktop\nDOCK_AUTOHIDE=true\nDOCK_ZOOM=false\n")
    assert_valid("empty_url", "PROFILE=minimal\nSTART_URL=\nBROWSER_AUTOSTART=false\n")
    assert_valid(
        "url_query_unicode_encoded",
        'START_URL="https://example.org/search?q=k%20test&lang=id&v=1#top"\n',
    )
    assert_valid("url_unicode", "START_URL=https://example.org/caf%C3%A9?x=1&y=2\n")
    assert_valid("software_render_mode", "BROWSER_COMPATIBILITY=software-rendering\nDISPLAY_MODE=1280x720\n")
    assert_valid("custom_browser_bin", "BROWSER_BINARY=/usr/bin/chromium\n")

    # 2. Invalid / hostile payloads (must be rejected cleanly without executing anything)
    marker = Path(tempfile.gettempdir()) / f"armbiandesk-pwned-{os.getpid()}"
    if marker.exists():
        marker.unlink()

    assert_invalid("unsupported_scheme_ftp", b"START_URL=ftp://example.org/file\n")
    assert_invalid("unsupported_scheme_js", b"START_URL=javascript:alert(1)\n")
    assert_invalid("option_disguised_as_url", b"START_URL=--no-sandbox\n")
    assert_invalid("url_with_space", b"START_URL=https://example.org/hello world\n")
    assert_invalid("unknown_key", b"UNKNOWN_KEY=1\n")
    assert_invalid("duplicate_key", b"PROFILE=minimal\nPROFILE=desktop\n")
    assert_invalid("invalid_profile", b"PROFILE=kde\n")
    assert_invalid("invalid_bool", b"KEEP_AWAKE=yes\n")
    assert_invalid("cmd_sub_dollar", f"START_URL=https://example.org/?x=$(touch {marker})\n".encode())
    assert_invalid("cmd_sub_backtick", f"START_URL=https://example.org/?x=`touch {marker}`\n".encode())
    assert_invalid("cmd_sub_brace", b"LANGUAGE=${PATH}\n")
    assert_invalid("newline_cr_injection", b"PROFILE=minimal\rSTART_URL=https://example.org/\n")
    assert_invalid("path_traversal_browser_bin", b"BROWSER_BINARY=/usr/bin/../../bin/sh\n")

    # 3. Symlink config file must be rejected
    with tempfile.TemporaryDirectory() as td:
        real_f = Path(td) / "real.conf"
        real_f.write_text("PROFILE=minimal\n", encoding="utf-8")
        sym_f = Path(td) / "sym.conf"
        sym_f.symlink_to(real_f)
        res = run_validate(sym_f)
        assert res.returncode != 0, "Expected symlink config to be rejected"

    assert not marker.exists(), "Shell injection executed during config validation!"
    print("PASS: T02 config parser safety and anti-injection (all cases passed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
