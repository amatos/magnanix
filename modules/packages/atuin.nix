# Aspect:    den.aspects.tui.atuin (included by base)
# Platforms: home-manager
# Purpose:   Atuin shell history: a searchable history database (Ctrl-R) for
#            bash, zsh and fish, synced between machines through atuin.sh.
{
  den.aspects.tui.atuin = {
    homeManager = {
      programs.atuin = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
        # Atuin binds only Ctrl-R; the up arrow keeps the shell's own history.
        flags = [ "--disable-up-arrow" ];
        settings = {
          # Sync history with Atuin's hosted server (log in once with
          # `atuin login`), at most every 5 minutes.
          auto_sync = true;
          sync_address = "https://api.atuin.sh";
          sync_frequency = "5m";
          # Fuzzy matching over the history of every host and session, not just
          # the current directory or session.
          search_mode = "fuzzy";
          filter_mode = "global";
          # One line per entry instead of the default multi-line layout.
          style = "compact";
          # No AI command suggestions.
          ai.enabled = false;
        };
      };
    };
  };
}
