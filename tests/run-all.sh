#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/tests/test_static.sh"
python3 "$ROOT_DIR/tests/test_config_parser.py"
"$ROOT_DIR/tests/test_install_lifecycle.sh"
"$ROOT_DIR/tests/test_session_mock.sh"
"$ROOT_DIR/tests/test_image_builder.sh"
"$ROOT_DIR/tests/test_release_sanitize.sh"

echo "=========================================="
echo "ALL ARMBIANDESK AUTOMATED TESTS PASSED"
echo "=========================================="
