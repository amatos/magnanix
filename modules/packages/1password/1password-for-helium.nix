# Helium uses the chrome plugin for 1password, but is unable to communicate with
# the 1password app by default, due to the issue described here:
# https://www.1password.community/1password-at-home-31/helium-browser-extension-not-connecting-to-mac-1password-app-25594
#
# In order to address the problem, we need to make sure that the Helium
# NativeMessagingHosts directory exists, and contains the 1password native messaging file.
#
# `macos._1passwordForHelium` rather than `macos.1passwordForHelium`: a Nix
# attribute name can't start with a digit without quoting, the same reason the
# main aspect is `_1password`.
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
