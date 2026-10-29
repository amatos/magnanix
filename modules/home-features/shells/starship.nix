{
  # Starship prompt. Home Manager adds the init hook to each enabled shell
  # (zsh, fish, bash) by default, so this works with whichever shells a user includes.
  den.aspects.shell.starship = {
    homeManager.programs.starship = {
      enable = true;

      # Written to ~/.config/starship.toml. These are Starship's own defaults, spelled
      # out as a starting point; change them here (https://starship.rs/config/).
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        add_newline = true;
        command_timeout = 500; # milliseconds

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };
    };
  };
}
