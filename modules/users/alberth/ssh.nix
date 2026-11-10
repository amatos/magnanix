# User:      alberth (den.aspects.alberth.ssh)
# Platforms: home-manager
# Purpose:   alberth's SSH client config (~/.ssh/config), starting from an empty
#            config (enableDefaultConfig = false) with a github.com entry.
#
# Notes:
# - The 1Password SSH agent (IdentityAgent) is added by den.aspects._1password,
#   so it's only set on hosts that run 1Password.
{
  den.aspects.alberth.ssh = {
    # The 1Password agent (IdentityAgent) comes from den.aspects._1password, so it
    # is only set on hosts that run 1Password.
    homeManager = {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."github.com" = {
          HostName = "github.com";
          User = "git";
        };
      };
    };
  };
}
