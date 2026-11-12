# Aspects:   den.aspects.thunderbird               (the mail client)
#            den.aspects.thunderbird.externalGnupg (opt-in; OpenPGP keys from GnuPG)
# Platforms: thunderbird: home-manager; externalGnupg: home-manager, darwin
# Purpose:   Thunderbird mail client, with a Home Manager-managed default
#            profile. `externalGnupg` lets it use secret keys held by GnuPG,
#            such as keys on a smartcard (YubiKey), which its built-in OpenPGP
#            can't.
#
# Notes:
# - Opt-in per user per host: include it from `den.aspects.<host>.provides.<user>`
#   (or from a user aspect that is included that way, like alberth.mail).
# - Uses nixpkgs' `thunderbird` on both NixOS and macOS (the macOS build is in
#   cache.nixos.org). On macOS Home Manager links the app into
#   ~/Applications/Home Manager Apps.
# - Home Manager writes profiles.ini (~/.thunderbird on Linux,
#   ~/Library/Thunderbird on macOS), so profiles created from Thunderbird's own
#   profile manager are dropped from it on the next switch.
# - Accounts come from Home Manager's `accounts.email.accounts.<name>` with
#   `thunderbird.enable = true`.
# - externalGnupg: Thunderbird loads GPGME and runs the user's own gpg
#   (programs.gpg.package), so it shares their agent and smartcard setup. Your
#   public key still has to be imported into Thunderbird's OpenPGP Key Manager
#   once. On macOS Thunderbird only looks for libgpgme in a few fixed
#   directories (LD_LIBRARY_PATH from the nixpkgs wrapper does nothing there),
#   so activation links Nix's libgpgme into /usr/local/lib.
{
  den.aspects.thunderbird = {
    homeManager = {
      programs.thunderbird = {
        enable = true;

        # Home Manager needs exactly one default profile to write profiles.ini.
        profiles.default.isDefault = true;
      };
    };

    externalGnupg = {
      # Thunderbird on macOS tries libgpgme.dylib in its own app bundle, the
      # default dyld locations (/usr/local/lib, /usr/lib), then /opt/local/lib and
      # /opt/homebrew/lib. Nothing else on these hosts installs libgpgme there.
      darwin =
        { pkgs, ... }:
        {
          system.activationScripts.postActivation.text = ''
            mkdir -p /usr/local/lib
            ln -sfn ${pkgs.gpgme}/lib/libgpgme.dylib /usr/local/lib/libgpgme.dylib
          '';
        };

      homeManager =
        { config, ... }:
        {
          programs.thunderbird.profiles.default = {
            # Sets mail.openpgp.allow_external_gnupg and installs gpgme.
            withExternalGnupg = true;

            # The gpg GPGME runs. Without this it uses the gnupg it was built
            # against; this keeps it on the same gpg as the user's shell.
            settings."mail.openpgp.alternative_gpg_path" = "${config.programs.gpg.package}/bin/gpg";
          };
        };
    };
  };
}
