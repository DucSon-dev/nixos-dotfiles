{ config, pkgs, ... }:

{
  # Docker Daemon
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Display Manager (Tuigreet)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  # OpenSSH Remote Access
  services.openssh.enable = true;
}
