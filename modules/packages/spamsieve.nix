# Aspect:    den.aspects.macos.spamsieve
# Platforms: darwin
# Purpose:   SpamSieve, a Bayesian spam filter for Apple Mail and other mail
#            clients, as a Homebrew cask.
{
  den.aspects.macos.spamsieve = {
    darwin = {
      homebrew.casks = [ "spamsieve" ];
    };
  };
}
