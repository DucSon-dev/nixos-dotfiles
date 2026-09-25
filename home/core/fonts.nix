{ pkgs, ... }:

{
  # Core System Typography and Fallback Fonts
  home.packages = with pkgs; [
    geist-font
    nerd-fonts.geist-mono
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
  ];

  fonts.fontconfig.enable = true;
}
