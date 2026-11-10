# Aspect:    den.aspects.audio.macos.audioHijack (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Audio Hijack, which records audio from any app or device, installed as a Homebrew cask.
{
  den.aspects.audio.macos.audioHijack = {
    darwin = {
      homebrew.casks = [ "audio-hijack" ];
    };
  };
}
