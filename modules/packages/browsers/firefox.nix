{
  den.aspects.browsers.firefox = {
    # The signed Mozilla build. 1Password checks the browser's code signature on
    # macOS, and the nixpkgs Firefox wrapper strips it, so the integration needs
    # the cask rather than a Nix package.
    darwin.homebrew.casks = [ "firefox" ];

    homeManager =
      { pkgs, lib, ... }:
      {
        programs.firefox = {
          enable = true;

          # Installed by the cask on macOS; Home Manager only manages the config there.
          package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;

          # Packages providing lib/mozilla/native-messaging-hosts. 1Password isn't
          # listed because it writes its own manifest into the same directory, which
          # Home Manager links into file by file, leaving that manifest in place.
          nativeMessagingHosts = [ ];

          # Written to the `org.mozilla.firefox` defaults domain on macOS.
          policies.ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
          };
        };
      };
  };
}
