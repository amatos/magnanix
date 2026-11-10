# Aspect:    den.aspects.github
# Platforms: home-manager
# Purpose:   The GitHub CLI (`gh`). Log in once with `gh auth login`.
{ ... }:
{
  # GitHub CLI (`gh`) via Home Manager.
  den.aspects.github.homeManager.programs.gh.enable = true;
}
