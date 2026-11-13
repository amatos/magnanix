# Host:      magnus (den.aspects.magnus)
# Platform:  aarch64-darwin (nix-darwin)
# Purpose:   The main Mac: desktop apps, App Store apps, development tools,
#            OrbStack, Tart (runs the darwintron and nixostron test VMs), the
#            Attic push watcher, certbot and Tailscale.
#
# Notes:
# - Users that include den.batteries.host-aspects also get the homeManager parts
#   of the aspects included here.
# - alberth is the primary user and signs commits with their GPG key here
#   (git.signing), because the key (on a YubiKey) is usable here.
# - Requests certificates for magnus.home.matos.cc and magnus.ts.matos.cc.
{
  den,
  inputs,
  lib,
  ...
}:
let
  computerName = "Magnus";
  hostName = lib.toLower computerName;
  certbotOwners = "alberth@matos.cc";
in
{
  den.hosts.aarch64-darwin.magnus = {
    users.alberth = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
    inherit hostName;
  };

  # Configuration specific to magnus
  den.aspects.magnus = {
    # System-level apps for this machine. Users that include
    # `den.batteries.host-aspects` also get the `homeManager` parts of these.
    includes = [
      den.aspects._1password
      den.aspects.attic.push
      den.aspects.audio
      den.aspects.browsers
      den.aspects.certbot
      den.aspects.claude
      den.aspects.elgato
      den.aspects.fonts
      den.aspects.game-streaming
      den.aspects.ghostty
      den.aspects.macos._1password
      den.aspects.macos.acorn
      den.aspects.macos.amphetamine
      den.aspects.macos.appleDeveloper
      den.aspects.macos.autoMounter
      den.aspects.macos.backgroundSwitcher
      den.aspects.macos.battleNet
      den.aspects.macos.boardGames
      den.aspects.macos.bookShelves
      den.aspects.macos.broadcasts
      den.aspects.macos.cleanShot
      den.aspects.macos.codePeek
      den.aspects.macos.contactsSync
      den.aspects.macos.crossOver
      den.aspects.macos.crystalFetch
      den.aspects.macos.darkroom
      den.aspects.macos.dropover
      den.aspects.macos.due
      den.aspects.macos.flexibits
      den.aspects.macos.flixFixer
      den.aspects.macos.hyperduck
      den.aspects.macos.hyperspace
      den.aspects.macos.iris
      den.aspects.macos.ivory
      den.aspects.macos.iwork
      den.aspects.macos.kaleidoscope
      den.aspects.macos.languageTool
      den.aspects.macos.ledgerWallet
      den.aspects.macos.mela
      den.aspects.macos.microsoftOffice
      den.aspects.macos.nepTunes
      den.aspects.macos.orbstack
      den.aspects.macos.paste
      den.aspects.macos.pastel
      den.aspects.macos.pixelSnap
      den.aspects.macos.pixelmator
      den.aspects.macos.reeder
      den.aspects.macos.safariExtensions
      den.aspects.macos.simpleComic
      den.aspects.macos.stecker
      den.aspects.macos.texStage
      den.aspects.macos.things
      den.aspects.macos.topNotch
      den.aspects.macos.tower
      den.aspects.macos.transmit
      den.aspects.macos.velja
      den.aspects.macos.windowsApp
      den.aspects.macos.zavala
      den.aspects.openssh
      den.aspects.steam
      den.aspects.tailscale
      den.aspects.tex
      den.aspects.tui.macos.tart
      den.aspects.zed
      den.aspects.zsa.voyager
    ];

    darwin = {
      system.stateVersion = 7;
      networking.computerName = computerName;

      local.certbot = {
        email = "${certbotOwners}";
        fqdns = [
          "${hostName}.home.matos.cc"
          "${hostName}.ts.matos.cc"
        ];
      };
    };
  };

  # alberth is the primary user on magnus, signs commits with the GPG key, reads mail
  # (Fastmail in Thunderbird), develops (language toolchains) and has their Mac
  # desktop (Dock and apps) here.
  den.aspects.magnus.provides.alberth.includes = [
    den.batteries.primary-user
    den.aspects.git.signing
    den.aspects.alberth.dev
    den.aspects.alberth.macDesktop
    den.aspects.alberth.mail
  ];
}
