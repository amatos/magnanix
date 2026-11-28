# Aspect:    den.aspects.macos.betterDisplay
# Platforms: darwin
# Purpose:   BetterDisplay, the display management tool (HiDPI scaling, virtual
#            screens, brightness and resolution control), as a Homebrew cask.
#            The cask updates itself (auto_updates); Pro is licensed in the app.
{
  den.aspects.macos.betterDisplay = {
    darwin = {
      homebrew.casks = [ "betterdisplay" ];
    };
  };
}
