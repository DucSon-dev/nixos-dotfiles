{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      # Typography
      font_family = "GeistMono Nerd Font";
      font_size = "11.5";
      bold_font = "auto";
      italic_font = "auto";

      # Ninja Slash & Smooth Motion
      cursor = "#fafafa";
      cursor_text_color = "#09090b";
      cursor_shape = "block";
      cursor_blink_interval = "0";
      cursor_trail = "1";
      cursor_trail_decay = "0.1 0.35";
      cursor_trail_start_threshold = "2";

      # Scrollback Buffer (Lưu tới 20,000 dòng log)
      scrollback_lines = 20000;

      # Liquid Glass & Styling
      background_opacity = "0.72";
      window_padding_width = "16";
      confirm_os_window_close = 0;

      # Native Wayland Decorations Suppression
      hide_window_decorations = "yes";
      linux_display_server = "wayland";
      wayland_titlebar_color = "background";

      # Clipboard Handling
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

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

    # Keybindings chuẩn xác
    keybindings = {
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+c"       = "copy_and_clear_or_interrupt";
      "ctrl+v"       = "paste_from_clipboard";
      "ctrl+shift+h" = "show_scrollback";
    };

    extraConfig = ''
      # Click chuột phải để Paste trực tiếp
      mouse_map right press ungrabbed paste_from_clipboard

      # Dump trực tiếp toàn bộ màn hình và scrollback vào wl-copy mà không bung overlay
      map ctrl+shift+a launch --type=background --stdin-source=@screen_scrollback wl-copy
    '';
  };
}
