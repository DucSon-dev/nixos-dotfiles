#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

# Toggle: Dismiss if already running
if pidof fuzzel >/dev/null 2>&1; then
    pkill -9 fuzzel
    exit 0
fi

BINDS_FILE="/etc/nixos/home/desktop/binds.kdl"
[[ ! -f "$BINDS_FILE" ]] && BINDS_FILE="/home/ducson/.config/niri/binds.kdl"

if [[ ! -f "$BINDS_FILE" ]]; then
    notify-send -a "Cheat Sheet" -u critical "Error" "binds.kdl not found."
    exit 1
fi

PARSED_BINDS=$(grep -E '^\s*(Mod\+|Print|XF86)' "$BINDS_FILE" | while IFS= read -r line; do
    KEY_PART=$(echo "$line" | sed -E 's/^\s*//' | awk '{print $1}')
    DESC_PART=$(echo "$line" | grep -oP '(?<=//\s).*' || echo "Execute Action")
    
    KEY_CLEAN=$(echo "$KEY_PART" | sed -E 's/Mod\+/Super + /g; s/Shift\+/Shift + /g; s/Ctrl\+/Ctrl + /g; s/Alt\+/Alt + /g')
    printf "%-26s ›  %s\n" "$KEY_CLEAN" "$DESC_PART"
done)

# Inherits SSOT colors and geometry directly from fuzzel.nix
echo -e "$PARSED_BINDS" | fuzzel \
    --dmenu \
    --prompt="⌨  Hotkeys › " \
    --width=62 \
    --lines=18
