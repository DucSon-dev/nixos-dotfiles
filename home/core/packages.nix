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
    kitty
    fastfetch
    lazygit
    
    # Icon & Cursor Fallbacks (Fix missing icon / purple checkerboard)
    adwaita-icon-theme
    vanilla-dmz
  ];
}
