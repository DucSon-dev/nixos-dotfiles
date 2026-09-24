{ pkgs, ... }:

{
  # Smart Zsh Configuration with Minimal Glass Prompt & Fast Completion
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    # Fish-like autosuggestions matching shadcn zinc palette
    autosuggestion = {
      enable = true;
      highlight = "fg=#71717a";
    };

    # Syntax highlighting (clean contrast)
    syntaxHighlighting.enable = true;

    # History retention rules
    history = {
      size = 10000;
      save = 10000;
      share = true;
      ignoreDups = true;
      path = "$HOME/.zsh_history";
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    initContent = ''
      # Smart Tab Autocompletion
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # Keybinding: Accept autosuggestion with Right Arrow or Ctrl+Space
      bindkey '^ ' autosuggest-accept
      bindkey '^E' autosuggest-accept

      # Auto-run fastfetch on interactive shell launch
      if [[ -z "$SSH_CONNECTION" && $- == *i* ]]; then
        fastfetch
      fi
    '';
  };
}
