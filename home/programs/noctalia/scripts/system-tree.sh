#!/usr/bin/env bash
set -eo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

# Toggle: Close fuzzel if already active
if pidof fuzzel >/dev/null 2>&1; then
  pkill -9 fuzzel
  exit 0
fi

# Dynamic runtime extraction
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_HOST="${HOSTNAME:-$(hostname)}"
KERNEL_INFO="$(uname -s) $(uname -r)"

if [[ -f /proc/cpuinfo ]]; then
  CPU_MODEL="$(grep -m1 "model name" /proc/cpuinfo | awk -F': ' '{print $2}' | sed -E 's/[[:space:]]+/ /g')"
  CPU_CORES="$(nproc 2>/dev/null || echo '12')"
  CPU_INFO="${CPU_MODEL} (${CPU_CORES}T)"
else
  CPU_INFO="x86_64 Processor"
fi

GPU_INFO="$(lspci 2>/dev/null | grep -E -i 'vga|3d|display' | awk -F': ' '{print $2}' | head -n1 | sed -E 's/^[[:space:]]+//' || echo 'Intel Graphics')"
MEM_INFO="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 " / " $2}' || echo 'N/A')"
DISK_USAGE="$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"

TOPOLOGY_REPORT=$(cat << TOPOLOGY
󰌽 OS / Kernel     ›  NixOS (${KERNEL_INFO})
 Compositor / WM ›  Niri Wayland (Dynamic Tiling)
 CPU Processor   ›  ${CPU_INFO}
󰢮 GPU Accelerator ›  ${GPU_INFO}
󰘚 System Memory   ›  ${MEM_INFO}
󰋊 Storage Inode   ›  ${DISK_USAGE}
────────────────────────────────────────────────────────────
📁 SYSTEM ARCHITECTURE (/etc/nixos/):
├─ flake.nix (Declarative Entrypoint & System Arguments)
├─ hosts/nixos/ (Machine Abstraction Layer)
│  ├─ hardware-configuration.nix
│  ├─ system.nix (Kernel, Memory, Bootloader)
│  ├─ services.nix (Docker & tuigreet)
│  └─ i18n.nix (Bamboo Input Method Engine)
└─ home/ (Declarative User Environment)
   ├─ core/ (fonts.nix, packages.nix)
   ├─ desktop/ (niri compositor & binds)
   └─ programs/ (noctalia, kitty, fuzzel, zsh)
TOPOLOGY
)

echo -e "$TOPOLOGY_REPORT" | fuzzel \
  --dmenu \
  --prompt="󱗼 Topology [${CURRENT_USER}@${CURRENT_HOST}] › " \
  --font="GeistMono Nerd Font:size=11" \
  --width=66 \
  --lines=18 \
  --horizontal-pad=24 \
  --vertical-pad=18 \
  --inner-pad=10 \
  --background-color=09090bee \
  --text-color=fafafaff \
  --border-color=ffffff24 \
  --border-width=1 \
  --border-radius=18
