# Aspect:    den.aspects.direnv
# Platforms: home-manager
# Purpose:   direnv, which loads a directory's .envrc (e.g. `use flake` for a dev
#            shell) on cd, with nix-direnv for cached, faster `use flake` and
#            shell hooks for bash, zsh, fish and Nushell.
{ ... }:
{
  # direnv, with nix-direnv (a faster, caching `use flake`) and shell integration.
  den.aspects.direnv.homeManager.programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
