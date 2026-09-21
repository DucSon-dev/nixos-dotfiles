{ lib, ... }:

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

  xdg.configFile."noctalia/colors.json" = {
    source = ./colors.json;
    force = true;
  };
  
  # Purge stale runtime palette cache on configuration switch
  home.activation.cleanNoctaliaCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f $HOME/.config/noctalia/colors.json
  '';
}
