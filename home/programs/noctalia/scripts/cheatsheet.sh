#!/usr/bin/env bash

# Close if another instance is already running
if pidof fuzzel >/dev/null; then
    pkill -9 fuzzel
    exit 0
fi

# Define Menu List: Label mapped to executable command
declare -A ACTIONS
ACTIONS["󰌌  SUPER + T        ❯  Launch Kitty Terminal"]="kitty"
ACTIONS["󰌌  SUPER + B        ❯  Launch Firefox Browser"]="brave"
ACTIONS["󰌌  SUPER + D        ❯  Application Drawer"]="fuzzel"
ACTIONS["󰌌  SUPER + S        ❯  Interactive Screenshot Area"]="niri msg action screenshot"
ACTIONS["󰌌  SUPER + Shift+S  ❯  Fullscreen Screenshot"]="niri msg action screenshot-screen"
ACTIONS["󰌌  SUPER + F        ❯  Maximize Active Column"]="niri msg action maximize-column"
ACTIONS["󰌌  SUPER + Shift+F  ❯  Fullscreen Window"]="niri msg action fullscreen-window"
ACTIONS["󰌌  SUPER + Space    ❯  Toggle Overview Mode"]="niri msg action toggle-overview"
ACTIONS["󰌌  SUPER + C        ❯  Center Focused Column"]="niri msg action center-column"
ACTIONS["󰌌  SUPER + Q        ❯  Close Focused Window"]="niri msg action close-window"
ACTIONS["󰌌  SUPER + H/L/←/→  ❯  Navigate Columns Left/Right"]=""
ACTIONS["󰌌  SUPER + J/K/↑/↓  ❯  Navigate Windows Up/Down"]=""
ACTIONS["󰌌  SUPER + 1..4     ❯  Switch Workspace 1 - 4"]=""
ACTIONS["󰌌  SUPER + Shift+E  ❯  Exit Session / Logout"]="niri msg action quit"

# Render items in sorted order
ITEMS=$(printf "%s\n" \
  "󰌌  SUPER + T        ❯  Launch Kitty Terminal" \
  "󰌌  SUPER + B        ❯  Launch Firefox Browser" \
  "󰌌  SUPER + D        ❯  Application Drawer" \
  "󰌌  SUPER + S        ❯  Interactive Screenshot Area" \
  "󰌌  SUPER + Shift+S  ❯  Fullscreen Screenshot" \
  "󰌌  SUPER + F        ❯  Maximize Active Column" \
  "󰌌  SUPER + Shift+F  ❯  Fullscreen Window" \
  "󰌌  SUPER + Space    ❯  Toggle Overview Mode" \
  "󰌌  SUPER + C        ❯  Center Focused Column" \
  "󰌌  SUPER + Q        ❯  Close Focused Window" \
  "󰌌  SUPER + H/L/←/→  ❯  Navigate Columns Left/Right" \
  "󰌌  SUPER + J/K/↑/↓  ❯  Navigate Windows Up/Down" \
  "󰌌  SUPER + 1..4     ❯  Switch Workspace 1 - 4" \
  "󰌌  SUPER + Shift+E  ❯  Exit Session / Logout")

CHOICE=$(echo -e "$ITEMS" | fuzzel --dmenu --prompt="⌨ Hotkeys ❯ " --width=45 --lines=14)

# Execute corresponding command if selected
if [[ -n "$CHOICE" && -n "${ACTIONS[$CHOICE]}" ]]; then
    eval "${ACTIONS[$CHOICE]} &"
fi
