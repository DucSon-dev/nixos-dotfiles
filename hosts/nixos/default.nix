{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ./services.nix
  ];

  # User Definition
  users.users.d6n = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];
  };

  # Compositor Session Integration
  programs.niri.enable = true;

  system.stateVersion = "24.11";
}
