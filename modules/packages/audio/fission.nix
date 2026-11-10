# Aspect:    den.aspects.audio.macos.fission (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Fission, a lossless audio editor, installed as a Homebrew cask.
{
  den.aspects.audio.macos.fission = {
    darwin = {
      homebrew.casks = [ "fission" ];
    };
  };
}
