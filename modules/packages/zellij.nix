# Aspect:    den.aspects.tui.zellij (included by base)
# Platforms: home-manager
# Purpose:   Zellij, a terminal multiplexer (like tmux), with its built-in
#            Dracula theme. Start it by hand with `zellij`.
{
  den.aspects.tui.zellij = {
    homeManager = {
      programs.zellij = {
        enable = true;
        # Don't auto-start or auto-attach a session in every new shell.
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableZshIntegration = false;

        # Zellij's built-in Dracula. Dracula PRO ships no zellij theme.
        settings.theme = "dracula";
      };
    };
  };
}
