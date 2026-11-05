{
  den.aspects.nushell = {
    # Home Manager writes config.nu and env.nu, and the other tools' Nushell
    # integrations (atuin, direnv, starship, yazi, zoxide) switch on with it.
    homeManager.programs.nushell = {
      enable = true;

      # Load home.sessionVariables (EDITOR, ...) when Nushell starts without
      # them, e.g. as the shell a terminal opens directly. Home Manager turns
      # this on by default from stateVersion 26.11; our users are on 26.05.
      loadSessionVariables = true;
    };
  };
}
