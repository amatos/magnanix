# Aspect:    den.aspects.cli.zoxide (included by base)
# Platforms: home-manager
# Purpose:   zoxide, a `cd` that learns your most-used directories (`z proj`
#            jumps to the best match), with bash, zsh and fish integration.
#
# Notes:
# - `cd` is aliased to `z` in zsh and fish, so plain `cd` also learns and
#   accepts fuzzy matches. Use `builtin cd` to bypass it.
{
  den.aspects.cli.zoxide = {
    homeManager =
      { ... }:
      let
        zoxideAliases = {
          # Every `cd` goes through zoxide (see the header).
          cd = "z";
        };
      in
      {
        programs = {
          fish.shellAliases = zoxideAliases;
          zsh.shellAliases = zoxideAliases;
          zoxide = {
            enable = true;
            enableFishIntegration = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
          };
        };
      };
  };
}
