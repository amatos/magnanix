# Aspect:    den.aspects.macos.appleDeveloper
# Platforms: darwin
# Purpose:   Apple's developer apps: Xcode, TestFlight, Developer and Swift
#            Playground.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.appleDeveloper = {
    darwin.homebrew.masApps = {
      "Xcode" = 497799835;
      "TestFlight" = 899247664;
      "Developer" = 640199958;
      "Swift Playground" = 1496833156;
    };
  };
}
