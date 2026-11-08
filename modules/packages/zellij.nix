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
