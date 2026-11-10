# Aspect:    den.aspects.macos.boardGames
# Platforms: darwin
# Purpose:   Board games: Goban (Go) and Gomoku.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.boardGames = {
    darwin.homebrew.masApps = {
      "Goban" = 646372172;
      "Gomoku" = 457851462;
    };
  };
}
