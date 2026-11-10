# Aspect:    den.aspects.audio.macos.piezo (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Piezo, a simple recorder for audio from any app, installed as a Homebrew cask.
{
  den.aspects.audio.macos.piezo = {
    darwin = {
      homebrew.casks = [ "piezo" ];
    };
  };
}
