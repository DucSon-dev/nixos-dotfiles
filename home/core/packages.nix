{ pkgs, ... }:

{
  home.packages = with pkgs; [
   
    # Dev & Tools
    nodejs_22
    pnpm
    yarn
    docker-compose
    git
    gh
    curl
    wget
    wl-clipboard
    swaybg
    noctalia-shell
    firefox
    brave
    kitty
    fastfetch
    lazygit
    nautilus
    
    # Knowledge Base & Note Taking
    obsidian
    
    # Media & Audio
    amberol
    playerctl
    
    # Audio Extraction & System Notification Tooling
    libnotify
    yt-dlp
    ffmpeg
    atomicparsley

    # Modern CLI Utilities
    fzf
    eza
    bat
    
    # Code Editors (Dual Setup)
    
    vscodium
   
    # System Utilities & Monitoring
    btop
    brightnessctl
    swaylock-effects
   
   # Productivity & Learning
    anki
    
   # Password Manager & Security
    keepassxc
   
    # Office Suite
    libreoffice-fresh
    
   # Icon & Cursor Fallbacks (Fix missing icon / purple checkerboard)
   adwaita-icon-theme
   papirus-icon-theme
   vanilla-dmz
   
   # GTK / Libadwaita GSettings & Schema Tooling
    glib
    gsettings-desktop-schemas   
  ];
}
