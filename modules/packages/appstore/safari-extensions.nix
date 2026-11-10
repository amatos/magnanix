# Aspect:    den.aspects.macos.safariExtensions
# Platforms: darwin
# Purpose:   Safari extensions.
#
# Notes:
# - Turn each one on in Safari > Settings > Extensions after the first switch.
# - 1Password for Safari is a separate aspect, `macos._1password`.
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.safariExtensions = {
    darwin.homebrew.masApps = {
      "Auto HD FPS for YouTube" = 1546729687;
      "Kagi for Safari" = 1622835804;
      "Obsidian Web Clipper" = 6720708363;
      "Privacy.com for Safari" = 6449850851;
      "Sink It" = 6449873635;
      "StopTheMadness Pro" = 6471380298;
      "Turn Off the Lights for Safari" = 1273998507;
      "Vinegar" = 1591303229;
    };
  };
}
