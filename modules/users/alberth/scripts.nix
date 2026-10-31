{
  den.aspects.alberth.scripts = {
    homeManager = { ... }: {
      home.file = {
        ".local/bin/control-dock.sh" = {
          source = ./scripts/control-dock.sh;
          executable = true;
        };
        ".local/bin/dollar.sh" = {
          source = ./scripts/dollar.sh;
          executable = true;
        };
        ".local/bin/extract.sh" = {
          source = ./scripts/extract.sh;
          executable = true;
        };
        ".local/bin/switch-yubikey" = {
          source = ./scripts/switch-yubikey;
          executable = true;
        };
        ".local/bin/velja-open.sh" = {
          source = ./scripts/velja-open.sh;
          executable = true;
        };
        ".local/bin/yubi-disable" = {
          source = ./scripts/yubi-disable;
          executable = true;
        };
        ".local/bin/yubi-enable" = {
          source = ./scripts/yubi-enable;
          executable = true;
        };
      };
    };
  };
}
