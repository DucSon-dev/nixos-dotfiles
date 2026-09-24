
{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion = {
      enable = true;
      highlight = "fg=#71717a";
    };

    syntaxHighlighting.enable = true;

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

      # Minimal Liquid Glass Capsule Prompt (macOS & shadcn Zinc theme)
      # Color palette tokens:
      # Zinc-800 Glass: bg 48;2;39;39;42, fg 38;2;250;250;250
      # Zinc-900 Glass: bg 48;2;24;24;27, fg 38;2;244;244;245
      # Accent Blue Chevron: fg 38;2;59;130;246
      PROMPT=$'%{\e[48;2;39;39;42;38;2;250;250;250m%} %n@%m %{\e[0m%} %{\e[48;2;24;24;27;38;2;244;244;245m%} 󰝰 %~ %{\e[0m%}\n%{\e[1;38;2;59;130;246m%}❯%{\e[0m%} '

      # Auto-run fastfetch on interactive shell launch
      if [[ -z "$SSH_CONNECTION" && $- == *i* ]]; then
        fastfetch
      fi
    '';
  };
}
