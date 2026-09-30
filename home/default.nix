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
    QT_QPA_PLATFORMTHEME = "gtk3";
    # Ensure Libadwaita / GTK4 applications locate GSettings schemas and icon themes
    XDG_DATA_DIRS = "$XDG_DATA_DIRS:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.adwaita-icon-theme}/share";
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

  # Direct GSettings / dconf schema synchronization for Libadwaita / GTK4 apps (Amberol)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "Adwaita";
    };
  };
  # FreeDesktop Universal Icon Fallback Chain & Missing Asset Aliases
  xdg.dataFile = {
    "icons/default/index.theme".text = ''
      [Icon Theme]
      Name=Default
      Comment=Default Fallback Icon Theme
      Inherits=Adwaita,Papirus-Dark,Papirus,hicolor
    '';

    "icons/hicolor/index.theme".text = ''
      [Icon Theme]
      Name=Hicolor
      Comment=Root Fallback Icon Theme
      Inherits=Adwaita,Papirus-Dark,Papirus
      Directories=scalable/apps,symbolic/apps

      [scalable/apps]
      Size=48
      MinSize=16
      MaxSize=512
      Type=Scalable

      [symbolic/apps]
      Size=16
      MinSize=16
      MaxSize=512
      Type=Scalable
    '';
    
    # Map missing 'input-keyboard' asset directly from Adwaita store
    "icons/hicolor/scalable/apps/input-keyboard.svg".source =
      "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/scalable/devices/input-keyboard-symbolic.svg";

    # System-wide fallbacks for unknown/broken app or notification icons
    "icons/hicolor/scalable/apps/image-missing.svg".source =
      "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/scalable/mimetypes/application-x-generic.svg";
    "icons/hicolor/scalable/apps/application-default-icon.svg".source =
      "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/scalable/mimetypes/application-x-generic.svg";
   
    # Map Amberol application icons directly to hicolor user data path
    "icons/hicolor/scalable/apps/io.bassi.Amberol.svg".source =
      "${pkgs.amberol}/share/icons/hicolor/scalable/apps/io.bassi.Amberol.svg";
    "icons/hicolor/symbolic/apps/io.bassi.Amberol-symbolic.svg".source =
      "${pkgs.amberol}/share/icons/hicolor/symbolic/apps/io.bassi.Amberol-symbolic.svg";
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
    ./programs/neovim.nix
  ];

  programs.home-manager.enable = true;
}
