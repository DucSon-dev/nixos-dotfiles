{ pkgs, ... }:

{
  # Hyprlock service and declarative appearance configuration
  programs.hyprlock = {
    enable = true;

    settings = {
      # Background canvas with subtle zinc blur
      background = [
        {
          monitor = "";
          path = "";
          color = "rgba(9, 9, 11, 0.92)"; # Dark Zinc #09090b
          blur_passes = 3;
          blur_size = 6;
          noise = 0.015;
          contrast = 0.9;
          brightness = 0.8;
        }
      ];

      # Minimalist clock display
      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgba(250, 250, 250, 0.95)"; # White Zinc #fafafa
          font_size = 48;
          font_family = "Geist";
          position = "0, 40";
          halign = "center";
          valign = "center";
          shadow_passes = 1;
          shadow_size = 3;
        }
        {
          monitor = "";
          text = "cmd[update:1000] date +'%A, %B %d'";
          color = "rgba(161, 161, 170, 0.8)"; # Muted Zinc #a1a1aa
          font_size = 14;
          font_family = "Geist";
          position = "0, -10";
          halign = "center";
          valign = "center";
        }
      ];

      # Circular Avatar profile image
      image = [
        {
          monitor = "";
          path = "/home/ducson/.face";
          size = 100;
          rounding = -1; # Perfect circle
          border_size = 1;
          border_color = "rgba(255, 255, 255, 0.12)"; # Subtle glass border
          position = "0, 150";
          halign = "center";
          valign = "center";
          reload_time = -1;
        }
      ];

      # Capsule pill password input field
      input-field = [
        {
          monitor = "";
          size = "260, 46";
          outline_thickness = 1;
          dots_size = 0.26;
          dots_spacing = 0.35;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgba(255, 255, 255, 0.15)";
          inner_color = "rgba(24, 24, 27, 0.75)"; # Zinc-900 glass
          font_color = "rgba(250, 250, 250, 1.0)";
          fade_on_empty = false;
          placeholder_text = "<span foreground='##71717a'>Password...</span>";
          hide_input = false;
          rounding = -1; # Pill shaped capsule
          check_color = "rgba(59, 130, 246, 0.8)";
          fail_color = "rgba(239, 68, 68, 0.8)";
          fail_text = "<i>Auth failed</i>";
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
