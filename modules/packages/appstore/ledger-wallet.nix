# Aspect:    den.aspects.macos.ledgerWallet
# Platforms: darwin
# Purpose:   Ledger Wallet, the companion app for Ledger hardware wallets.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.ledgerWallet = {
    darwin.homebrew.masApps."Ledger Wallet" = 1361671700;
  };
}
