# Aspect:    den.aspects.macos.crossOver
# Platforms: darwin
# Purpose:   CodeWeavers CrossOver, which runs Windows apps and games on macOS
#            without a Windows licence, as a Homebrew cask. Paid; needs a licence
#            after the trial.
{
  den.aspects.macos.crossOver = {
    darwin = {
      homebrew.casks = [ "crossover" ];
    };
  };
}
