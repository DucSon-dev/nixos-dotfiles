#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

if pidof fuzzel >/dev/null 2>&1; then
  pkill -9 fuzzel
  exit 0
fi

BINDS_FILE=""
if [[ -f "/etc/nixos/home/desktop/binds.kdl" ]]; then
  BINDS_FILE="/etc/nixos/home/desktop/binds.kdl"
elif [[ -f "/etc/nixos/home/desktop/niri.kdl" ]]; then
  BINDS_FILE="/etc/nixos/home/desktop/niri.kdl"
fi

[[ -z "$BINDS_FILE" ]] && exit 1

declare -A ACTIONS
RAW_MENU=""

while IFS= read -r line || [[ -n "$line" ]]; do
  trimmed=$(echo "$line" | sed -E 's/^[[:space:]]+//')
  
  if [[ ! "$trimmed" =~ ^(Mod\+|Print) ]]; then
    continue
  fi
  [[ ! "$trimmed" =~ "{" ]] && continue

  key=$(echo "$trimmed" | sed -E 's/^[[:space:]]*([^ {]+).*/\1/' | sed 's/Mod/SUPER/g')
  [[ "$key" =~ "Slash" ]] && continue

  desc=""
  if [[ "$trimmed" =~ //(.*)$ ]]; then
    desc=$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  fi
  [[ -z "$desc" ]] && desc="Execute Action"

  cmd=""
  if [[ "$trimmed" =~ spawn[[:space:]]+(.*)\; ]]; then
    raw_cmd="${BASH_REMATCH[1]}"
    cmd=$(echo "$raw_cmd" | awk -v FPAT='([^ "]+)|("[^"]+")' '{for(i=1;i<=NF;i++){gsub(/"/, "", $i); printf "%s ", $i}}')
  elif [[ "$trimmed" =~ \{[[:space:]]*([^;{}]+)\; ]]; then
    action=$(echo "${BASH_REMATCH[1]}" | tr -d '[:space:]')
    cmd="niri msg action $action"
  fi

  label=$(printf "󰌌  %-22s ›  %s" "$key" "$desc")
  RAW_MENU+="${label}"$'\n'
  ACTIONS["$label"]="$cmd"
done < "$BINDS_FILE"

SELECTED=$(printf "%s" "$RAW_MENU" | fuzzel \
  --dmenu \
  --prompt="⌨  Hotkeys › " \
  --font="GeistMono Nerd Font:size=11" \
  --width=58 \
  --lines=16 \
  --horizontal-pad=24 \
  --vertical-pad=16 \
  --inner-pad=10 \
  --line-height=26 \
  --background-color=09090bee \
  --text-color=fafafaff \
  --prompt-color=fafafaff \
  --match-color=60a5faff \
  --selection-color=27272ae6 \
  --selection-text-color=ffffffff \
  --selection-match-color=93c5fdff \
  --border-color=ffffff24 \
  --border-width=1 \
  --border-radius=18)

if [[ -n "$SELECTED" && -n "${ACTIONS[$SELECTED]}" ]]; then
  eval "${ACTIONS[$SELECTED]} &"
fi
