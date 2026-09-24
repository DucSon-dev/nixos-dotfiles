{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  # Global Cursor & Default Browser Variables
  home.sessionVariables = {
    XCURSOR_THEME = "Vanilla-DMZ";
    XCURSOR_SIZE = "24";
    BROWSER = "brave";
    DEFAULT_BROWSER = "brave";
  };

  # Set Brave as Default Browser for Web Protocols and MIME types
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
      "application/pdf" = "brave-browser.desktop";
    };
  };

  # GTK Theme and FreeDesktop Icon Management
  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  imports = [
    ./core/packages.nix
    ./core/fonts.nix
    ./desktop/niri.nix
    ./desktop/hyprlock.nix
    ./programs/kitty.nix
    ./programs/fuzzel.nix
    ./programs/noctalia
    ./programs/fastfetch.nix
    ./programs/zsh.nix
    ./programs/starship.nix
  ];

  programs.home-manager.enable = true;
}
