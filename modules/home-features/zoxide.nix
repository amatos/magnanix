{
  den.aspects.tui.zoxide = {
    homeManager =
      { ... }:
      let
        zoxideAliases = {
          # Safety prompts
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
