#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="${SCRIPT_DIR}/TestMpris.qml"

echo "=== Running Headless MPRIS v2 Bridge & Mock Feeder Test Harness ==="

nix-shell -p qt6.qtdeclarative playerctl --run "
  export QT_QPA_PLATFORM=offscreen
  QML_BIN=\$(which qml)
  QT_ROOT=\$(dirname \${QML_BIN})/..
  export QML2_IMPORT_PATH=\"${SCRIPT_DIR}/mock-imports:\${QT_ROOT}/lib/qt-6/qml:\${QML2_IMPORT_PATH:-}\"
  qml -I \"${SCRIPT_DIR}/..\" \"${TEST_FILE}\"
"

echo "=== Mock Feeder & MPRIS Suite PASS ==="
