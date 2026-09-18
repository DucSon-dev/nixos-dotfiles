{ pkgs, ... }:

{
  # Smart Zsh Configuration with Autosuggestions and Completion
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      share = true;
      ignoreDups = true;
    };

    initContent = ''
      # Smart Tab Autocompletion (Interactive menu & case-insensitive)
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # Fastfetch auto-run on interactive sessions
      if [[ -z "$SSH_CONNECTION" && $- == *i* ]]; then
        fastfetch
      fi
    '';
  };
}
