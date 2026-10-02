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
      netcat-openbsd
      (pkgs.writeShellScriptBin "fluent-flyout-manager" ''
        exec /nix/store/sm3wl9r36x33y1sgn68ydn0wv0ax7y7v-noctalia-qs-0.0.12/bin/quickshell -p ~/.config/fluent-flyout/FlyoutManager.qml "$@"
      '')
    ];

    xdg.configFile."fluent-flyout/shell.qml".source = ./shell.qml;
    xdg.configFile."fluent-flyout/MediaFlyout.qml".source = ./MediaFlyout.qml;
    xdg.configFile."fluent-flyout/OsdFlyout.qml".source = ./OsdFlyout.qml;
    xdg.configFile."fluent-flyout/TaskbarCapsule.qml".source = ./TaskbarCapsule.qml;
    xdg.configFile."fluent-flyout/FlyoutManager.qml".source = ./FlyoutManager.qml;
    xdg.configFile."fluent-flyout/config.json".source = ./config.json;

    # Systemd User Service: Runs standalone background daemon within graphical session
    systemd.user.services.fluent-flyout = {
      Unit = {
        Description = "FluentFlyout Layer-Shell Daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "/nix/store/sm3wl9r36x33y1sgn68ydn0wv0ax7y7v-noctalia-qs-0.0.12/bin/quickshell -p %h/.config/fluent-flyout";
        Restart = "always";
        RestartSec = "2s";
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/1000"
          "WAYLAND_DISPLAY=wayland-1"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
