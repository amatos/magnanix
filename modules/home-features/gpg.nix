{ den, ... }:
{
  den.aspects.gpg = {
    # `homebrew.enable` and `nix-homebrew` are set by the `homebrew` aspect
    # (modules/den/homebrew.nix), which is included for every host.
    darwin = {
      homebrew.casks = [ "gpg-suite@nightly" ];

      # GPG Suite's installer puts its tools on PATH two ways, which can shadow the
      # Nix gnupg: an /etc/paths.d entry for /usr/local/MacGPG2/bin, and a
      # /usr/local/bin/gpg symlink to MacGPG2's gpg2. The cask re-creates both on
      # install/upgrade, so remove them after every activation (nix-darwin runs the
      # Homebrew step before postActivation). The symlink is only removed if it
      # points at GPG Suite, so an unrelated /usr/local/bin/gpg is left alone.
      system.activationScripts.postActivation.text = ''
        rm -f /etc/paths.d/MacGPG2
        if [ "$(readlink /usr/local/bin/gpg)" = "/usr/local/MacGPG2/bin/gpg2" ]; then
          rm -f /usr/local/bin/gpg
        fi
      '';
    };

    homeManager =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        meta = (den.aspects.${config.home.username} or { }).meta or { };
        hasKey = meta ? gpgKey;
      in
      {
        programs.gpg = {
          enable = true;
          # home-manager's programs.gpg module already mkDefaults most of the old
          # gpg.conf (drduh/YubiKey-Guide) — personal-*-preferences, cert/s2k algos,
          # no-comments, no-emit-version, keyid-format, list/verify-options,
          # with-fingerprint, require-cross-certification, no-symkey-cache. Only
          # the settings below are additional or diverge from those defaults.
          settings = {
            charset = "utf-8";
            no-greeting = true;
            require-secmem = true;
            armor = true;
            auto-key-locate = "clear,local,wkd,dane";
          }
          // lib.optionalAttrs hasKey { default-key = meta.gpgKey; };

          # GnuPG smartcard glue — make scdaemon defer to pcscd (Linux only).
          #
          # Root cause this fixes: there is exactly one smartcard reader (a built-in
          # Realtek CCID reader, or a USB YubiKey acting as its own reader). By default
          # GnuPG's scdaemon uses its *internal* CCID driver and opens that reader
          # directly via libusb, which locks out pcscd — pcscd then logs
          # `OpenUSBByName() Can't claim interface … LIBUSB_ERROR_BUSY` and every other
          # PC/SC consumer (OpenSC PKCS#11, `ssh-add -s`, yubioath) is starved. Whichever
          # daemon grabs the reader first wins, so the smartcard "works" only
          # intermittently depending on boot/login race order.
          #
          # `disable-ccid` makes scdaemon talk to the reader through pcscd instead of its
          # own driver (pcscd must be running with the ccid plugin), and `pcsc-shared`
          # lets the card be opened by several PC/SC clients at once. Net effect: gpg
          # (via scdaemon → pcscd), OpenSC, ssh PKCS#11 and yubioath all share the single
          # reader instead of fighting over it.
          scdaemonSettings = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
            disable-ccid = true; # route through pcscd, don't grab the reader directly
            pcsc-shared = true; # allow concurrent PC/SC access to the card
          };

          # Home Manager imports these on activation and applies the trust level
          # using the fingerprint read from the key file.
          publicKeys = lib.optional (meta ? gpgPublicKey) {
            source = meta.gpgPublicKey; # e.g. ./alberth.pub.asc
            trust = "ultimate";
          };
        };
      };
  };
}
