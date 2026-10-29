{ den, ... }: {
  den.aspects.shell.bash = {
    includes = [
      den.aspects.shell.shellAliases
      den.aspects.shell.posixFunctions
      den.aspects.shell.starship
    ];
    homeManager =
      {
        config,
        pkgs,
        ...
      }:

      {
        programs.bash = {
          enable = true;
          # dotDir = "${config.xdg.configHome}/bash";
          # initContent = ''
          #   [ -f ${config.xdg.configHome}/op/plugins.sh ] && source ${config.xdg.configHome}/op/plugins.sh
          # '';
        };
      };
  };
}
