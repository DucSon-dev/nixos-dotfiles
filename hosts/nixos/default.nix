{ config, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ./services.nix
    ./i18n.nix
  ];

  # Primary User Configuration dynamically resolved from flake arguments
  users.users.${username} = {
    isNormalUser = true;
    initialPassword = "123"; # Default temporary password to prevent lockout
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];
  };

 # Enable Niri system integration and systemd user services
  programs.niri.enable = true;

  system.stateVersion = "24.11";
}
