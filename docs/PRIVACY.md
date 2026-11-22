# Privacy & Release Hygiene

- **Zero Telemetry**: ArmbianDesk does not phone home or transmit usage metrics.
- **Sanitized `status --json`**: Output includes only versions, arch, profile name, component presence, and aggregate memory/load/temp counters — never tab URLs, window/chat titles, IP/MAC addresses, SSIDs, or usernames.
- **Browser Profiles**: Stored privately per user under `$XDG_CONFIG_HOME/armbiandesk/chromium` (`0700`) and are never backed up, copied, or cleared by `install`/`uninstall`/`restore`.
- **Release Sanitization**: Use `./tools/package-source.sh` to build clean allowlist source archives checked by `./tools/sanitize-check.sh`.
