{ pkgs, ... }:

{
  home.packages = with pkgs; [
    geist-font
    inter
    nerd-fonts.jetbrains-mono
  ];

  fonts.fontconfig.enable = true;
}
