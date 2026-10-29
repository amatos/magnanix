{ ... }:
{
  # direnv, with nix-direnv (a faster, caching `use flake`) and shell integration.
  den.aspects.direnv.homeManager.programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
