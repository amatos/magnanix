# Aspect:    den.aspects.audio.macos.soundsource (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   SoundSource, per-app volume, output device and effects control, installed as a Homebrew cask.
{
  den.aspects.audio.macos.soundsource = {
    darwin = {
      homebrew.casks = [ "soundsource" ];
    };
  };
}
