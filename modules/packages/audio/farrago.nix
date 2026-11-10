# Aspect:    den.aspects.audio.macos.farrago (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Farrago, a soundboard for playing audio clips live, installed as a Homebrew cask.
{
  den.aspects.audio.macos.farrago = {
    darwin = {
      homebrew.casks = [ "farrago" ];
    };
  };
}
