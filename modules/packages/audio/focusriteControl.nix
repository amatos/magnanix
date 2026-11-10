# Aspect:    den.aspects.audio.macos.focusriteControl (part of den.aspects.audio)
# Platforms: darwin
# Purpose:   Focusrite Control 2, the control app for Focusrite audio interfaces, installed as a Homebrew cask.
{
  den.aspects.audio.macos.focusriteControl = {
    darwin = {
      homebrew.casks = [ "focusrite-control-2" ];
    };
  };
}
