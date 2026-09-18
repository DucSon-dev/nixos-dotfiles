{ pkgs, ... }:

{
  home.packages = with pkgs; [
    geist-font
    inter
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
  ];

  fonts.fontconfig.enable = true;
}	

