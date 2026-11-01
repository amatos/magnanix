{ den, ... }: {
  den.aspects._1password = {
    includes = [
      (den.batteries.unfree [
        "1password"
        "1password-cli"
        "1password-gui"
      ])

      # Parametric include: `user` is only available in user context, and the
      # NixOS config has no `home.username`.
      (
        { user, ... }:
        {
          nixos.programs = {
            _1password.enable = true;
            _1password-gui = {
              enable = true;
              # Certain features, including CLI integration and system authentication support,
              # require enabling PolKit integration on some desktop environments (e.g. Plasma).
              polkitPolicyOwners = [ user.userName ];
            };
          };
        }
      )
    ];

    homeManager.programs.bash.initExtra = ''
      source <(op completion bash)
    '';

    homeManager.programs.fish.interactiveShellInit = ''
      op completion fish | source
    '';

    homeManager.programs.zsh.initContent = ''
      eval "$(op completion zsh)"
      compdef _op op
    '';

    darwin = {
      programs = {
        _1password = {
          enable = true;
        };
        _1password-gui = {
          enable = true;
        };
      };
    };
  };
}
