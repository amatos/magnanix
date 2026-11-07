# CodeWeavers CrossOver, which runs Windows apps and games on macOS without a
# Windows licence, as a Homebrew cask. CrossOver is paid software and needs a
# licence after its trial.
{
  den.aspects.macos.crossOver = {
    darwin = {
      homebrew.casks = [ "crossover" ];
    };
  };
}
