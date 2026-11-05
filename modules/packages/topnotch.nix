# TopNotch, which hides the MacBook notch behind a black menu bar, as a Homebrew
# cask. It is free and isn't in nixpkgs or the App Store.
{
  den.aspects.macos.topNotch = {
    darwin = {
      homebrew.casks = [ "topnotch" ];
    };
  };
}
