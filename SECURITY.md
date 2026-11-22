# Security Policy

## Security Architecture
- **Browser Isolation**: Chromium always runs under the unprivileged target user with OS sandboxing and site isolation enabled. Remote debugging ports are never opened by ArmbianDesk.
- **No `eval` Config Parsing**: `/etc/armbiandesk/armbiandesk.conf` and user overrides are parsed strictly as key-value data via a Python whitelist validator (`lib/config.sh`), rejecting shell substitutions, control characters, symlinks, and invalid URL schemes.
- **Safe USB Flashing & Root Separation**: `armbiandesk-image flash` enforces removable USB transport validation (`lsblk RM=1`) and refuses to touch system/mounted disks.
- **Manifest Privacy**: Installation manifests and backups are stored under `0700`/`0600` permissions and excluded from source distributions.

## Reporting a Vulnerability
Please report security issues privately to the repository maintainer with steps to reproduce, affected version, and minimal proof-of-concept details. Do not include private keys, cookies, or user credentials in issue reports.
