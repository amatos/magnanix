{
  den.aspects.alberth.ssh = {
    homeManager =
      { config, pkgs, ... }:
      let
        onePassPath =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
          else
            "${config.home.homeDirectory}/.1password/agent.sock";
      in
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          includes = [ "${config.home.homeDirectory}/.ssh/1Password/config" ];
          settings = {
            "github.com" = {
              HostName = "github.com";
              User = "git";
            };

            "*" = {
              IdentityAgent = onePassPath;
            };
          };
        };
      };
  };
}
