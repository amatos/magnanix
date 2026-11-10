# Aspect:    den.aspects.macos.transmit
# Platforms: darwin
# Purpose:   Transmit file transfer client (SFTP, S3, WebDAV, ...).
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.transmit = {
    darwin.homebrew.masApps."Transmit" = 1436522307;
  };
}
