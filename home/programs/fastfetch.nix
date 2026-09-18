{ ... }:

{
  # Fastfetch System Telemetry Display Layout
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
}
