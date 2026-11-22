# Aspect:    den.aspects.macos.alfred
# Platforms: darwin
# Purpose:   Alfred 6 by Running with Crayons, the launcher and productivity
#            app, as a Homebrew cask (not packaged in nixpkgs).
#
# Notes:
# - nixpkgs' `alfred` is an unrelated package: the B.A.T.M.A.N. mesh
#   networking tool, Linux only.
# - The `alfred` cask tracks the current major version (Alfred 6). It is
#   `auto_updates`, so Alfred updates itself and `brew upgrade` leaves it
#   alone. A new major version is a new paid upgrade; the cask moves to it
#   and the old one is kept as `alfred@<n>`.
# - The Powerpack licence is entered in the app. Settings can be synced
#   through Alfred's own sync folder (Advanced > Syncing).
# - Removing this aspect zaps the cask (homebrew onActivation.cleanup = "zap"),
#   which trashes ~/Library/Application Support/Alfred (workflows, snippets,
#   clipboard history) unless settings live in a sync folder.
{
  den.aspects.macos.alfred = {
    darwin = {
      homebrew.casks = [ "alfred" ];
    };
  };
}
