# Aspect:    den.aspects.audio.macos.airfoil (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Airfoil, which sends any app's audio to AirPlay, Bluetooth and Chromecast speakers, installed as a Homebrew cask.
{
  den.aspects.audio.macos.airfoil = {
    darwin = {
      homebrew.casks = [ "airfoil" ];
    };
  };
}
