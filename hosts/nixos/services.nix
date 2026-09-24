{ config, pkgs, ... }:

{
  # Docker daemon configuration
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Display manager configuration (tuigreet)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Single-line invocation with remember flags for seamless user and session switching
        command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-user-session --window-padding 2 --container-padding 2 --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Safe TTY configuration for Wayland compositors (prevents framebuffer detachment)
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
  };

  # OpenSSH remote access
  services.openssh.enable = true;
}
