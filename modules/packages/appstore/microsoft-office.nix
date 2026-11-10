# Aspect:    den.aspects.macos.microsoftOffice
# Platforms: darwin
# Purpose:   Microsoft Office: Word, Excel and PowerPoint, plus OneDrive.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.microsoftOffice = {
    darwin.homebrew.masApps = {
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "OneDrive" = 823766827;
    };
  };
}
