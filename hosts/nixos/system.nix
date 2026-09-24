{ config, pkgs, ... }:

{
  # 1. Bootloader & Network Configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Ho_Chi_Minh";

  # Silent Boot: Clean console without breaking DRM framebuffer
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "systemd.show_status=auto"
  ];

  # 2. PAM Configuration for Screen Locking
  security.pam.services.hyprlock = {};
  security.pam.services.login = {};
  # 3. Memory Optimization and Garbage Collection
  zramSwap.enable = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  # 4. Global Icon Themes & Desktop Portals
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    hicolor-icon-theme
    librsvg
    gdk-pixbuf
  ];

  # 5. Polkit Rules for Power Management
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
           action.id == "org.freedesktop.login1.suspend" ||
           action.id == "org.freedesktop.login1.hibernate") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
   # 6. Enable Zsh system-wide and configure user shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
