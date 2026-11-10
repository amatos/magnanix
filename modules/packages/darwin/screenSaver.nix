# Aspect:    den.aspects.darwin.screenSaver (part of darwin.customizations)
# Platforms: darwin
# Purpose:   Require the password 5 seconds after the screen saver starts or
#            the display sleeps, so a brief idle can be undone without logging in.
{
  den.aspects.darwin.screenSaver = {
    darwin.system.defaults.screensaver = {
      askForPassword = true;
      askForPasswordDelay = 5; # 0 = immediately
    };
  };
}
