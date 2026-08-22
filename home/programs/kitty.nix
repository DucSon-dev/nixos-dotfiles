{ pkgs, ... }:

{
  # 1. Kitty Terminal configuration (Glass & Blur)
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "GeistMono Nerd Font";
      font_size = "11.5";
      bold_font = "auto";
      italic_font = "auto";
      background_opacity = "0.85";
      window_padding_width = "14";
      confirm_os_window_close = 0;
      hide_window_decorations = "yes";

      # Color Scheme (shadcn Dark Zinc)
      background = "#09090b";
      foreground = "#fafafa";
      selection_background = "#27272a";
      selection_foreground = "#fafafa";

      color0  = "#18181b"; color1  = "#ef4444"; color2  = "#22c55e"; color3  = "#eab308";
      color4  = "#3b82f6"; color5  = "#a855f7"; color6  = "#06b6d4"; color7  = "#f4f4f5";
      color8  = "#71717a"; color9  = "#f87171"; color10 = "#4ade80"; color11 = "#facc15";
      color12 = "#60a5fa"; color13 = "#c084fc"; color14 = "#22d3ee"; color15 = "#ffffff";
    };
  };

  # 2. Fastfetch Clean Dynamic Layout Matching the Target Design
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "type": "kitty-direct",
        "source": "/home/d6n/.config/fastfetch/assets/logo.png",
        "width": 26,
        "height": 13,
        "padding": {
          "top": 1,
          "left": 2,
          "right": 4
        }
      },
      "display": {
        "separator": "  "
      },
      "modules": [
        // --- 1. HARDWARE SECTION ---
        { "type": "custom", "format": "┌─────────────── Hardware ───────────────┐", "outputColor": "bright_black" },
        { "type": "cpu", "key": "│ ", "keyColor": "yellow", "format": "{1} ({2}) @ {4} GHz" },
        { "type": "gpu", "key": "│ 󰢮", "keyColor": "yellow", "format": "{2} @ {4} GHz [{3}]" },
        { "type": "memory", "key": "│ 󰘚", "keyColor": "yellow", "format": "{1} GiB / {2} GiB ({3})" },
        { "type": "disk", "key": "│ 󰋊", "keyColor": "green", "format": "{1} GiB / {2} GiB ({3}) - {9}" },
        { "type": "custom", "format": "└────────────────────────────────────────┘", "outputColor": "bright_black" },
        "break",

        // --- 2. SOFTWARE SECTION ---
        { "type": "custom", "format": "┌─────────────── Software ───────────────┐", "outputColor": "bright_black" },
        { "type": "os", "key": "│  OS", "keyColor": "blue", "format": "{3} {12}" },
        { "type": "kernel", "key": "│  󰌽", "keyColor": "blue", "format": "Linux {2}" },
        { "type": "packages", "key": "│  󰏖", "keyColor": "blue", "format": "{1} (nix)" },
        { "type": "terminal", "key": "│  ", "keyColor": "blue", "format": "{1}" },
        { "type": "terminalfont", "key": "│  ", "keyColor": "blue", "format": "{1}" },
        { "type": "shell", "key": "│  󱆃", "keyColor": "blue", "format": "{1} {4}" },
        { "type": "wm", "key": "│  WM", "keyColor": "cyan", "format": "{1}" },
        { "type": "custom", "format": "└────────────────────────────────────────┘", "outputColor": "bright_black" },
        "break",

        // --- 3. UPTIME & AGE SECTION ---
        { "type": "custom", "format": "┌───────────── Uptime / Age ─────────────┐", "outputColor": "bright_black" },
        { "type": "uptime", "key": "│ Uptime", "keyColor": "magenta", "format": "{1} days, {2} hours, {3} mins" },
        { "type": "custom", "format": "└────────────────────────────────────────┘", "outputColor": "bright_black" }
      ]
    }
  '';

  # 3. Interactive Bash Shell Hook
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ -z "$SSH_CONNECTION" && $- == *i* ]]; then
        fastfetch
      fi
    '';
  };
}
