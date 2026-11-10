# Aspect:    den.aspects.tui.yubikey (included by base)
# Platforms: nixos, home-manager
# Purpose:   YubiKey Manager (`ykman`), and on NixOS the pcscd smartcard daemon,
#            which gpg (see gpg.nix), OpenSC and ykman talk to the key through.
{
  den.aspects.tui.yubikey = {
    nixos = {
      services.pcscd.enable = true;
    };

    homeManager = { pkgs, ... }: {
      home = {
        packages = [
          pkgs.yubikey-manager
        ];
      };
    };
  };
}
