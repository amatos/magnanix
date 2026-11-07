# Blizzard's Battle.net client as a Homebrew cask. The cask runs Blizzard's
# installer, which puts Battle.net in /Applications and keeps it updated.
{
  den.aspects.macos.battleNet = {
    darwin = {
      homebrew.casks = [ "battle-net" ];
    };
  };
}
