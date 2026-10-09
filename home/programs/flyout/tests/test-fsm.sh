#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="${SCRIPT_DIR}/TestFSM.qml"

echo "=== Running Headless StateMachine QML Test Harness ==="

nix-shell -p qt6.qtdeclarative --run "
  export QT_QPA_PLATFORM=offscreen
  QML_BIN=\$(which qml)
  QT_ROOT=\$(dirname \${QML_BIN})/..
  export QML2_IMPORT_PATH=\"\${QT_ROOT}/lib/qt-6/qml:\${QML2_IMPORT_PATH:-}\"
  qml -I \"${SCRIPT_DIR}/..\" \"${TEST_FILE}\"
"

echo "=== Test Suite PASS ==="
