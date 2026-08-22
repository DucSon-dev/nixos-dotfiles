{ pkgs, ... }:

{
  home.username = "d6n";
  home.homeDirectory = "/home/d6n";
  home.stateVersion = "24.11";

  imports = [
    ./core/packages.nix
    ./core/fonts.nix
    ./desktop/niri.nix
    ./programs/kitty.nix
    ./programs/fuzzel.nix
    ./programs/noctalia
  ];

  programs.home-manager.enable = true;
}
