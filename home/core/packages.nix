{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
  ];
}
