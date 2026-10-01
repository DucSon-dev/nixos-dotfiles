{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fluentFlyout;
in
{
  options.programs.fluentFlyout = {
    enable = lib.mkEnableOption "FluentFlyout Layer-Shell Modules and Manager Engine";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      playerctl
      wireplumber
      brightnessctl
    ];

    xdg.configFile."fluent-flyout/config.json".source = ./config.json;
    xdg.configFile."flyout/TaskbarCapsule.qml".source = ./TaskbarCapsule.qml;
  };
}
