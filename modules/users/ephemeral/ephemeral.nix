{ den, ... }:
let
  username = "ephemeral";
in
{
  # Disposable test user for darwintron and nixostron. Its secrets
  # (secrets/users/ephemeral.yaml) hold fake values only.
  den.aspects.ephemeral = {
    includes = [
      den.batteries.define-user
      den.batteries.host-aspects
    ];

    homeManager = {
      # Set to the release ephemeral's Home Manager was first set up with
      home.stateVersion = "26.05";
    };

    user = {
      createHome = true;
      description = "Ephemeral test user";
    };

    os =
      { pkgs, ... }:
      {
        users.users.${username}.shell = pkgs.zsh;
      };

    # See the matching block in modules/users/alberth/alberth.nix.
    darwin =
      { pkgs, ... }:
      {
        environment.shells = [ pkgs.zsh ];

        system.activationScripts.postActivation.text = ''
          if [ "$(dscl . -read /Users/${username} UserShell)" != "UserShell: /run/current-system/sw/bin/zsh" ]; then
            echo "setting ${username}'s login shell to Nix zsh..." >&2
            dscl . -create /Users/${username} UserShell /run/current-system/sw/bin/zsh
          fi
        '';
      };
  };
}
