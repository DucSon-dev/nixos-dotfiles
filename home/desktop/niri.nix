{ ... }:

{
  # Map modular KDL configurations directly into ~/.config/niri/
  xdg.configFile."niri/config.kdl".source = ./niri.kdl;
  xdg.configFile."niri/binds.kdl".source = ./binds.kdl;
  xdg.configFile."niri/rules.kdl".source = ./rules.kdl;
  xdg.configFile."niri/input.kdl".source = ./input.kdl;
  xdg.configFile."niri/animations.kdl".source = ./animations.kdl;
  xdg.configFile."niri/outputs.kdl".source = ./outputs.kdl;
}
