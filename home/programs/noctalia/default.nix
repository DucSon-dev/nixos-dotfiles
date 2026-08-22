{ ... }:

{
  xdg.configFile."noctalia/settings.json" = {
    source = ./settings.json;
    force = true;
  };
  xdg.configFile."noctalia/scripts/cheatsheet.sh" = {
    source = ./scripts/cheatsheet.sh;
    executable = true;
    force = true;
  };
}
