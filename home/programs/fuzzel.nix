{ pkgs, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "GeistMono Nerd Font:size=11";
        terminal = "kitty";
        layer = "overlay";
        width = 56;
        lines = 14;
        horizontal-pad = 22;
        vertical-pad = 16;
        inner-pad = 10;
        line-height = 24;
      };

      colors = {
        # Liquid Glass Base (Zinc-950 with 85% opacity)
        background = "09090bd9";
        
        # Crisp White Text (Zinc-50) for High Contrast Readability
        text = "fafafaff";
        prompt = "fafafaff";
        input = "fafafaff";
        
        # Specular Focus Ring (1px Liquid Glass boundary)
        border = "ffffff24";
        
        # Selection Highlight (Zinc-800 Glass + Pure White Text)
        selection = "27272ae6";
        selection-text = "ffffffff";
        
        # Search Matching Accents (Clean Monochromatic Ice / Blue)
        match = "60a5faff";
        selection-match = "93c5fdff";
      };

      border = {
        width = 1;
        radius = 18;
      };
    };
  };
}
