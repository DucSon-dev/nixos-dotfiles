{ pkgs, ... }:

{
  # Vietnamese Input Method Configuration (fcitx5-bamboo)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-bamboo
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };

  # Wayland Environment Variables for Input Method Engine
  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    QT_IM_MODULE = "fcitx";
  };
}
