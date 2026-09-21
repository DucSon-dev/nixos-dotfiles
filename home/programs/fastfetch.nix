{ ... }:

{
  # Fastfetch System Telemetry Display Layout (Clean Open-Box UnixPorn Style)
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "type": "small",
        "padding": {
          "top": 1,
          "left": 2,
          "right": 3
        }
      },
      "display": {
        "separator": "  "
      },
      "modules": [
        // --- 1. HARDWARE SECTION ---
        { "type": "custom", "format": "╭─ Hardware ──────────────────────────────────────────", "outputColor": "white" },
        { "type": "cpu", "key": "│ ", "keyColor": "yellow", "format": "{1} ({2}) @ {4} GHz" },
        { "type": "gpu", "key": "│ 󰢮", "keyColor": "yellow", "format": "{2} [{3}]" },
        { "type": "memory", "key": "│ 󰘚", "keyColor": "yellow", "format": "{1} / {2} ({3})" },
        { "type": "disk", "key": "│ 󰋊", "keyColor": "green", "format": "{1} / {2} ({3}) - {9}" },
        { "type": "custom", "format": "╰─────────────────────────────────────────────────────", "outputColor": "white" },
        "break",

        // --- 2. SOFTWARE SECTION ---
        { "type": "custom", "format": "╭─ Software ──────────────────────────────────────────", "outputColor": "white" },
        { "type": "os", "key": "│  OS", "keyColor": "blue", "format": "{3} {12}" },
        { "type": "kernel", "key": "│ 󰌽", "keyColor": "blue", "format": "Linux {2}" },
        { "type": "packages", "key": "│ 󰏖", "keyColor": "blue", "format": "{1} (nix)" },
        { "type": "terminal", "key": "│ ", "keyColor": "blue", "format": "{1}" },
        { "type": "terminalfont", "key": "│ ", "keyColor": "blue", "format": "{1}" },
        { "type": "shell", "key": "│ 󱆃", "keyColor": "blue", "format": "{1} {4}" },
        { "type": "wm", "key": "│  WM", "keyColor": "cyan", "format": "{1}" },
        { "type": "custom", "format": "╰─────────────────────────────────────────────────────", "outputColor": "white" },
        "break",

        // --- 3. UPTIME & AGE SECTION ---
        { "type": "custom", "format": "╭─ Uptime / Age ──────────────────────────────────────", "outputColor": "white" },
        { "type": "uptime", "key": "│ Uptime", "keyColor": "magenta", "format": "{1} days, {2} hours, {3} mins" },
        { "type": "custom", "format": "╰─────────────────────────────────────────────────────", "outputColor": "white" }
      ]
    }
  '';
}
