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
