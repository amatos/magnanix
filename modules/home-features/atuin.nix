{
  den.aspects.tui.atuin = {
    homeManager = {
      programs.atuin = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
        flags = [ "--disable-up-arrow" ];
        settings = {
          auto_sync = true;
          search_mode = "fuzzy";
          sync_address = "https://api.atuin.sh";
          sync_frequency = "5m";
          filter_mode = "global";
          style = "compact";
          ai.enabled = false;
        };
      };
    };
  };
}
