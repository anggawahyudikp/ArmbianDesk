# Contributing to ArmbianDesk

Thank you for contributing to ArmbianDesk!

## Ground Rules
1. **Clean Identity & Privacy**: Never commit real user profiles, cookies, local/production IP addresses, private domains, SSH keys, raw device dumps, or third-party vendor artwork without verified redistribution provenance.
2. **Safety First**:
   - Never run browsers as `root` or disable Chromium's sandbox (`--no-sandbox`) by default.
   - Keep configuration parsing strictly data-only (never `source` or `eval` user configs).
   - Keep desktop and image-builder tests isolated via `--destdir` / fixtures / `--dry-run`.
3. **Testing Requirements**:
   Run the full automated suite before opening a PR:
   ```bash
   ./tests/run-all.sh
   ```
   All shell files must pass per-file `bash -n` (and `shellcheck` where available), and the sanitization scanner (`tools/sanitize-check.sh`) must report zero issues.
