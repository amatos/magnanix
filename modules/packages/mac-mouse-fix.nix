# Aspect:    den.aspects.macos.macMouseFix
# Platforms: darwin
# Purpose:   Mac Mouse Fix, as a Homebrew cask, so a third-party mouse's side
#            buttons (4 and 5) go back and forward in browsers and Finder.
#
# Notes:
# - It needs Accessibility permission (System Settings > Privacy & Security >
#   Accessibility) after the first launch.
# - Its button mappings are set in the app, not here; see
#   documentation/macos.md.
{
  den.aspects.macos.macMouseFix = {
    darwin = {
      homebrew.casks = [ "mac-mouse-fix" ];
    };
  };
}
