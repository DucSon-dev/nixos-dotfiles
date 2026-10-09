#!/usr/bin/env bash
# ==============================================================================
# Dynamic Deployment Engine with Liquid Glass Spinner & Stream Telemetry
# Style Spec: shadcn Dark Zinc | High-Performance Non-Blocking TTY Poller
# ==============================================================================


AUTO_APPROVE=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes|--non-interactive)
      AUTO_APPROVE=true
      shift
      ;;
  esac
done



set -o pipefail

# --- 1. Terminal Styles & Color Tokens (shadcn Dark Zinc) ---
readonly CLR_RESET=$'\033[0m'
readonly CLR_MUTED=$'\033[38;2;113;113;122m'    # Zinc-500
readonly CLR_TEXT=$'\033[38;2;250;250;250m'     # Zinc-50
readonly CLR_ACCENT=$'\033[38;2;59;130;246m'    # Blue-500
readonly CLR_SUCCESS=$'\033[38;2;34;197;94m'    # Green-500
readonly CLR_WARN=$'\033[38;2;234;179;8m'       # Yellow-500
readonly CLR_ERROR=$'\033[38;2;239;68;68m'      # Red-500

readonly SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
readonly REPO_DIR="/etc/nixos"
readonly LOG_DIR="/dev/shm/nixos_deploy_${UID}"
mkdir -p "$LOG_DIR"
readonly LOG_FILE="${LOG_DIR}/deploy.log"

# --- 2. Signal Trapping & Cursor Restoration ---
cleanup() {
  local exit_code=$?
  printf "\033[?25h\n"
  if [[ -n "${CURRENT_PID:-}" ]] && kill -0 "$CURRENT_PID" 2>/dev/null; then
    kill -TERM "$CURRENT_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Hide cursor during active animation
printf "\033[?25l"

# --- 3. UI Helpers ---
print_badge() {
  local step="$1"
  local title="$2"
  printf "\n%s[%s]%s %s%s%s\n" "$CLR_ACCENT" "$step" "$CLR_RESET" "$CLR_TEXT" "$title" "$CLR_RESET"
}

# --- 4. Core Telemetry & Spinner Engine ---
run_with_telemetry() {
  local label="$1"
  shift
  local cmd=("$@")

  : > "$LOG_FILE"
  
  "${cmd[@]}" > "$LOG_FILE" 2>&1 &
  CURRENT_PID=$!

  local frame=0
  local spinner_len=${#SPINNER_CHARS[@]}
  local status_line=""
  local speed_info=""
  local task_info=""

  while kill -0 "$CURRENT_PID" 2>/dev/null; do
    local char="${SPINNER_CHARS[$frame]}"
    local raw_log
    raw_log=$(tail -n 1 "$LOG_FILE" 2>/dev/null | tr -d '\r')

    if [[ "$raw_log" =~ ([0-9]+(\.[0-9]+)?\ [KMG]iB/s|[0-9]+(\.[0-9]+)?\ [KMG]B/s) ]]; then
      speed_info="[${BASH_REMATCH[1]}]"
    fi

    if [[ "$raw_log" =~ (fetching|downloading|evaluating|building|copying)[[:space:]]+([^,;]+) ]]; then
      local action="${BASH_REMATCH[1]}"
      local target="${BASH_REMATCH[2]}"
      target=$(basename "$target" | cut -c 1-28)
      task_info="${action} ${target}"
    elif [[ -n "$raw_log" ]]; then
      task_info=$(echo "$raw_log" | tr -s ' ' | cut -c 1-32)
    else
      task_info="Processing evaluation tree..."
    fi

    printf "\r\033[K %s%s%s %s%s%s %s%s%s %s%s%s" \
      "$CLR_ACCENT" "$char" "$CLR_RESET" \
      "$CLR_TEXT" "$label" "$CLR_RESET" \
      "$CLR_WARN" "$speed_info" "$CLR_RESET" \
      "$CLR_MUTED" "$task_info" "$CLR_RESET"

    frame=$(( (frame + 1) % spinner_len ))
    sleep 0.08
  done

  wait "$CURRENT_PID"
  local status=$?
  CURRENT_PID=""

  if [[ $status -eq 0 ]]; then
    printf "\r\033[K %s✔%s %s%s%s %s[Completed]%s\n" \
      "$CLR_SUCCESS" "$CLR_RESET" "$CLR_TEXT" "$label" "$CLR_RESET" "$CLR_MUTED" "$CLR_RESET"
    return 0
  else
    printf "\r\033[K %s✘%s %s%s%s %s[Failed]%s\n\n" \
      "$CLR_ERROR" "$CLR_RESET" "$CLR_TEXT" "$label" "$CLR_RESET" "$CLR_ERROR" "$CLR_RESET"
    printf "%s--- Error Diagnostics (Tail 15 Lines) ---%s\n" "$CLR_MUTED" "$CLR_RESET"
    tail -n 15 "$LOG_FILE"
    printf "%s----------------------------------------%s\n" "$CLR_MUTED" "$CLR_RESET"
    return 1
  fi
}

# ==============================================================================
# Execution Flow
# ==============================================================================
cd "$REPO_DIR"

print_badge "1/4" "Inspecting Workspace Topology"
CHANGED=$(git status --short || true)
if [[ -z "$CHANGED" ]]; then
  printf " %s✔ Working tree clean, zero unstaged delta.%s\n" "$CLR_MUTED" "$CLR_RESET"
else
  printf "%s" "$CHANGED" | sed "s/^/  ${CLR_WARN}›${CLR_RESET} /"
  printf "\n"
fi

print_badge "2/4" "Syntax Validation & Dependency Audit"
run_with_telemetry "Validating Flake AST" nix flake check --extra-experimental-features "nix-command flakes"

if [[ -f "home/desktop/niri.kdl" ]] && command -v niri >/dev/null 2>&1; then
  run_with_telemetry "Validating Niri Config" niri validate --config "home/desktop/niri.kdl"
fi

print_badge "3/4" "Evaluating System Derivations"
HOST_NAME="${HOSTNAME:-$(hostname)}"
FLAKE_TARGET=".#${HOST_NAME}"

run_with_telemetry "Dry-building Generation" nixos-rebuild dry-build --flake "$FLAKE_TARGET"

print_badge "4/4" "Deployment Confirmation"
if [[ "$AUTO_APPROVE" == true ]]; then
  CONFIRM="y"
  printf " %sAuto-approval flag detected. Proceeding with deployment...%s\n" "$CLR_WARN" "$CLR_RESET"
else
  printf "\033[?25h"
  read -p " Ready to switch into new generation? (y/N) " -n 1 -r CONFIRM
  echo
fi

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  git add .
  printf "\033[?25l"
  run_with_telemetry "Switching System & Symlinks" sudo nixos-rebuild switch --flake "$FLAKE_TARGET"
  printf "\n %s✔ All modules synchronized successfully.%s\n\n" "$CLR_SUCCESS" "$CLR_RESET"
else
  printf " %sDeployment aborted by user.%s\n\n" "$CLR_MUTED" "$CLR_RESET"
fi
