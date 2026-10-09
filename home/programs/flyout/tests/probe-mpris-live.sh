#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLYOUT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QS_BIN="/nix/store/sm3wl9r36x33y1sgn68ydn0wv0ax7y7v-noctalia-qs-0.0.12/bin/quickshell"

echo "=== Running Headless Live MPRIS Diagnostic Probe ==="

# Ensure symlink for core resolution within tests directory
ln -sfn "${FLYOUT_DIR}/core" "${SCRIPT_DIR}/core"

LOG_FILE=$(mktemp /tmp/qs-probe-live-XXXXXX.log)

set +e
timeout 3s "${QS_BIN}" -p "${SCRIPT_DIR}/ProbeLive.qml" --allow-duplicate > "${LOG_FILE}" 2>&1
EXIT_CODE=$?
set -e

cat "${LOG_FILE}"

if grep -q "PROBE_LIVE_SUCCESS" "${LOG_FILE}"; then
  LIVE_TITLE=$(grep "PROBE_LIVE_SUCCESS" "${LOG_FILE}" | head -n 1)
  echo ""
  echo "✔ Diagnostic Assertion PASS: ${LIVE_TITLE}"
  rm -f "${LOG_FILE}"
  exit 0
else
  echo ""
  echo "✘ Diagnostic Assertion FAILED: Live properties did not update or playback is stopped."
  rm -f "${LOG_FILE}"
  exit 1
fi
