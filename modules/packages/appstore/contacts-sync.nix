# Aspect:    den.aspects.macos.contactsSync
# Platforms: darwin
# Purpose:   Contacts Sync, which syncs Google Contacts with macOS Contacts.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.contactsSync = {
    darwin.homebrew.masApps."Contacts Sync" = 451691288;
  };
}
