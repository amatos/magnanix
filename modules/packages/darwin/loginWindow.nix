# Aspect:    den.aspects.darwin.loginWindow (part of darwin.customizations)
# Platforms: darwin
# Purpose:   Login window: no guest account, and a list of users to click rather
#            than empty name and password fields.
{
  den.aspects.darwin.loginWindow = {
    darwin.system.defaults.loginwindow = {
      # No Guest User account (macOS offers one by default).
      GuestEnabled = false;
      # false = list of users with pictures; true = blank name and password fields.
      SHOWFULLNAME = false;
    };
  };
}
