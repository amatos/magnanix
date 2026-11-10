# Aspect:    den.aspects.nushell (included by base)
# Platforms: home-manager
# Purpose:   Nushell, with Home Manager writing config.nu and env.nu so the
#            atuin, direnv, starship, yazi and zoxide integrations load in it.
#
# Notes:
# - No eza aliases here: Nushell keeps its built-in, structured `ls`.
{
  den.aspects.nushell = {
    homeManager.programs.nushell = {
      enable = true;

      # Load home.sessionVariables (EDITOR, ...) when Nushell starts without
      # them, e.g. as the shell a terminal opens directly. Home Manager turns
      # this on by default from stateVersion 26.11; our users are on 26.05.
      loadSessionVariables = true;
    };
  };
}
