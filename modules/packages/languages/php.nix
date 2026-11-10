# Aspect:    den.aspects.php
# Platforms: home-manager
# Purpose:   PHP, Composer (built on the same PHP) and intelephense (unfree);
#            ~/.config/composer/vendor/bin is on PATH for global requires.
{ den, ... }:
{
  den.aspects.php = {
    # intelephense is free to use, but its license is proprietary.
    includes = [ (den.batteries.unfree [ "intelephense" ]) ];

    homeManager =
      { config, pkgs, ... }:
      {
        # Binaries installed with `composer global require` (COMPOSER_HOME
        # defaults to ~/.config/composer).
        home.sessionPath = [ "${config.xdg.configHome}/composer/vendor/bin" ];

        home.packages = with pkgs; [
          php # runtime and CLI
          php.packages.composer # dependency manager, built against the same PHP
          intelephense # language server (LSP)
        ];
      };
  };
}
