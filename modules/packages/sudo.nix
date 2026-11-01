{
  den.aspects.sudo = {
    nixos = {
      security = {
        sudo.enable = false;
        sudo-rs = {
          enable = true;
          wheelNeedsPassword = false;
        };
      };
    };

    darwin = {
      security.pam.services.sudo_local.touchIdAuth = true;
    };

    # "wheel" is a NixOS-only users.users.<name>.extraGroups concept (not
    # supported by nix-darwin's users.users submodule), so it's declared
    # directly under `nixos` (keyed per user) instead of the generic `user`
    # class, which routes unconditionally to whichever OS class the host is.
    includes = [
      (
        { user, ... }:
        {
          nixos.users.users.${user.userName}.extraGroups = [ "wheel" ];
        }
      )
    ];
  };
}
