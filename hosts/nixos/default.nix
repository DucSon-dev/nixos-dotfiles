{ config, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ./services.nix
  ];

  # Primary User Configuration dynamically resolved from flake arguments
  users.users.${username} = {
    isNormalUser = true;
    initialPassword = "123"; # Default temporary password to prevent lockout
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];
  };

  # Display Manager (Tuigreet) & Session Management
  programs.niri.enable = true;
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  system.stateVersion = "24.11";
}
