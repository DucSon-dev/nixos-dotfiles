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

  # 3. Memory Optimization and Declarative Garbage Collection
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
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      niri = {
        default = [ "gnome" "gtk" ];
      };
    };
  };

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
  programs.dconf.enable = true;
  users.defaultUserShell = pkgs.zsh;
  
  # 7. System-wide Core Packages and CLI Utilities (ĐOẠN MỚI THÊM)
  environment.systemPackages = with pkgs; [
    git
    coreutils
  ];

  # 8. Pre-shutdown Git Auto-Snapshot Service (Zero Disk Bloat, Instant Execution)
  systemd.services.nixos-auto-snapshot = {
    description = "Automatic Git working tree snapshot before shutdown";
    wantedBy = [ "poweroff.target" "reboot.target" "halt.target" ];
    before = [ "poweroff.target" "reboot.target" "halt.target" ];
    unitConfig = {
      DefaultDependencies = "no";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      TimeoutStopSec = "10s";
      ExecStop = pkgs.writeShellScript "pre-shutdown-snapshot" ''
        REPO_DIR="/etc/nixos"
        if [ -d "$REPO_DIR/.git" ]; then
          cd "$REPO_DIR"
          export PATH="${pkgs.git}/bin:${pkgs.coreutils}/bin:$PATH"
          if [ -n "$(${pkgs.git}/bin/git status --porcelain)" ]; then
            ${pkgs.git}/bin/git add -A
            ${pkgs.git}/bin/git commit -m "chore(auto): snapshot working tree before shutdown at $(date '+%Y-%m-%d %H:%M:%S')" || true
          fi
        fi
      '';
    };
  };
}
