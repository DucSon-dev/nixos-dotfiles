#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="${SCRIPT_DIR}/TestOsd.qml"

echo "=== Running Headless System OSD Bridge Test Harness ==="

nix-shell -p qt6.qtdeclarative playerctl --run "
  export QT_QPA_PLATFORM=offscreen
  QML_BIN=\$(which qml)
  QT_ROOT=\$(dirname \${QML_BIN})/..
  export QML2_IMPORT_PATH=\"${SCRIPT_DIR}/mock-imports:\${QT_ROOT}/lib/qt-6/qml:\${QML2_IMPORT_PATH:-}\"
  qml -I \"${SCRIPT_DIR}/..\" \"${TEST_FILE}\"
"

echo "=== OSD Test Suite PASS ==="
