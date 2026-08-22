#!/usr/bin/env bash
set -e

REPO_DIR="/etc/nixos"
cd "$REPO_DIR"

echo "=== [1/4] Checking Modified Files ==="
nix-shell -p git --run "git status --short"

echo -e "\n=== [2/4] Validating Nix Flake Syntax ==="
nix flake check

echo -e "\n=== [3/4] Dry-run Build (Test without applying) ==="
nixos-rebuild dry-build --flake .#nixos
echo "✔ Syntax and build test: Passed successfully!"

echo -e "\n=== [4/4] Deploy Confirmation ==="
read -p "Do you want to rebuild and apply changes now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    nix-shell -p git --run "git add ."
    sudo nixos-rebuild switch --flake .#nixos
    echo "✔ System updated successfully!"
fi
