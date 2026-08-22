{ ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Geist:size=12";
        prompt = "❯ ";
        terminal = "kitty";
        layer = "overlay";
        width = 45;
      };
      colors = {
        background = "09090be6";
        text = "fafafaff";
        selection = "27272ae6";
        selection-text = "fafafaff";
        border = "ffffff1f";
        match = "3b82f6ff";
      };
      border = {
        width = 1;
        radius = 18;
      };
    };
  };
}
