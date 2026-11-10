# Aspect:    den.aspects.macos.languageTool
# Platforms: darwin
# Purpose:   LanguageTool grammar and spell checker.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.languageTool = {
    darwin.homebrew.masApps."LanguageTool" = 1534275760;
  };
}
