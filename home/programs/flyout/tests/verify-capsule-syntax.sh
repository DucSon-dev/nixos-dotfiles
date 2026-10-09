#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Validating Nix AST ==="
nix-instantiate --parse /etc/nixos/home/programs/flyout/default.nix >/dev/null
echo "Nix AST Validated Clean."

echo "=== 2. Engine Type & Runtime Check (Quickshell) ==="
QS_BIN="/nix/store/sm3wl9r36x33y1sgn68ydn0wv0ax7y7v-noctalia-qs-0.0.12/bin/quickshell"
CONFIG_PATH="/etc/nixos/home/programs/flyout"

# Execute quickshell for 2 seconds; expect exit code 124 (timeout) or 0
LOG_FILE=$(mktemp /tmp/qs-capsule-test-XXXXXX.log)
set +e
timeout 2s "${QS_BIN}" -p "${CONFIG_PATH}" --allow-duplicate > "${LOG_FILE}" 2>&1
EXIT_CODE=$?
set -e

cat "${LOG_FILE}"

# Check exit code
if [ "${EXIT_CODE}" -ne 0 ] && [ "${EXIT_CODE}" -ne 124 ]; then
  echo "FAIL: Quickshell exited unexpectedly with code ${EXIT_CODE}"
  rm -f "${LOG_FILE}"
  exit 1
fi

# Check for QML type assignment errors, ReferenceErrors, or syntax faults
if grep -Ei "(ReferenceError|Unable to assign|Cannot assign to|Type .* unavailable|failed to load component)" "${LOG_FILE}"; then
  echo "FAIL: Detected QML runtime type/reference errors in engine output."
  rm -f "${LOG_FILE}"
  exit 1
fi

rm -f "${LOG_FILE}"
echo "=== Verification Gate PASS: Zero Type Invariant Violations ==="
