# Aspect:    den.aspects.tzdata (included by base)
# Platforms: nixos
# Purpose:   Sets the system time zone to America/New_York. (macOS sets its
#            time zone itself, in System Settings.)
{
  den.aspects.tzdata = {
    nixos = {
      time.timeZone = "America/New_York";
    };
  };
}
