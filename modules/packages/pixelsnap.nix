# PixelSnap 2, the on-screen measuring tool, as a Homebrew cask. It isn't in
# nixpkgs or the App Store; the license is bought from pixelsnap.com.
{
  den.aspects.macos.pixelSnap = {
    darwin = {
      homebrew.casks = [ "pixelsnap" ];
    };
  };
}
