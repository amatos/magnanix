# Aspect:    den.aspects.macos.appInspection
# Platforms: darwin
# Purpose:   Tools for inspecting apps and installers before trusting them, as
#            Homebrew casks: Apparency (app bundles: signing, notarization,
#            entitlements), Suspicious Package (.pkg contents and install
#            scripts) and What's Your Sign? (code-signing info from Finder).
{
  den.aspects.macos.appInspection = {
    darwin = {
      homebrew.casks = [
        "apparency"
        "suspicious-package"
        "whatsyoursign"
      ];
    };
  };
}
