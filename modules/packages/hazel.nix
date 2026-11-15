# Aspect:    den.aspects.macos.hazel
# Platforms: darwin
# Purpose:   Hazel by Noodlesoft, rule-based automatic file organisation, as a
#            Homebrew cask (not packaged in nixpkgs).
#
# Notes:
# - Only the app is managed here. Rules are synced per folder through Hazel's
#   Rule Sync to a file in iCloud Drive, and the licence is entered in the app.
{
  den.aspects.macos.hazel = {
    darwin = {
      homebrew.casks = [ "hazel" ];
    };
  };
}
