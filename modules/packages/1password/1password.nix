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

    homeManager =
      { config, pkgs, ... }:
      let
        home = config.home.homeDirectory;

        # Where the 1Password app serves its SSH agent (Settings > Developer >
        # Use the SSH agent). The macOS path has a space, so it is quoted for ssh_config.
        agentSocket =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "\"${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
          else
            "${home}/.1password/agent.sock";
      in
      {
        programs.bash.initExtra = ''
          source <(op completion bash)
        '';

        programs.fish.interactiveShellInit = ''
          op completion fish | source
        '';

        programs.zsh.initContent = ''
          eval "$(op completion zsh)"
          compdef _op op
        '';

        # Route SSH through the 1Password agent, on hosts that include this aspect.
        # This doesn't enable programs.ssh; it only takes effect for users whose
        # own config does (alberth's ssh aspect). The include is 1Password's SSH
        # bookmarks file; ssh skips it while it doesn't exist.
        programs.ssh = {
          includes = [ "${home}/.ssh/1Password/config" ];
          settings."*".IdentityAgent = agentSocket;
        };
      };

    # On macOS, 1Password and its CLI come from Homebrew casks. The GUI must live
    # in /Applications for browser integration and its code-signature checks.
    darwin.homebrew.casks = [
      "1password"
      "1password-cli"
    ];
  };
}
