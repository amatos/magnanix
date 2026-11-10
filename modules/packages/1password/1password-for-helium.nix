# Aspect:    den.aspects.macos._1passwordForHelium
# Platforms: home-manager (macOS only; does nothing on Linux)
# Purpose:   Lets Helium's 1Password extension talk to the 1Password app by
#            installing 1Password's native messaging host manifest into Helium's
#            profile (NativeMessagingHosts/com.1password.1password.json).
#
# Notes:
# - Why: Helium uses the Chrome 1Password extension, but 1Password only writes
#   its manifest for browsers it knows about, so without this the extension
#   says it can't connect to the app. See
#   https://www.1password.community/1password-at-home-31/helium-browser-extension-not-connecting-to-mac-1password-app-25594
# - Named `_1password...` because a Nix attribute name can't start with a digit
#   without quoting.
{
  den.aspects.macos._1passwordForHelium = {
    # home.file creates the parent directories, so this also makes sure
    # NativeMessagingHosts exists. The path only exists on macOS.
    homeManager =
      { lib, pkgs, ... }:
      lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.file."Library/Application Support/net.imput.helium/NativeMessagingHosts/com.1password.1password.json".source =
          ./com.1password.1password.json;
      };
  };
}
