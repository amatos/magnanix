# Host:      fortuna (den.aspects.fortuna)
# Platform:  x86_64-linux (NixOS)
# Purpose:   AMD (CPU and GPU) desktop running Hyprland with the Noctalia shell,
#            on LUKS + btrfs laid out by disko (_disk-config.nix).
#
# Notes:
# - It has a second NVMe drive reserved for Windows 11. Never put NixOS data on
#   it; install steps and the rules that keep Windows possible are below.
# - Audio defaults to the GPU's HDMI output (WirePlumber priority rule).
# - magnus's first-choice remote builder (x86_64-linux, and aarch64-linux under
#   QEMU); pushes its builds to Attic. See documentation/remote-builders.md.
# - NetworkManager handles networking (Noctalia's Wi-Fi widget uses it).
# - Requests certificates for fortuna.home.matos.cc and fortuna.ts.matos.cc
#   (for Syncthing and the like later; Sunshine keeps its own self-signed one,
#   since Moonlight pins the certificate it paired with).
{ den, ... }:
let
  hostName = "fortuna";
  certbotOwners = "alberth@matos.cc";
in
{
  # Den sets nixpkgs.hostPlatform from this key; it matches the x86_64-linux in
  # _hardware-configuration.nix.
  den.hosts.x86_64-linux.fortuna.users.alberth = { };

  # Configuration specific to fortuna: an AMD (CPU and GPU) desktop running Hyprland.
  #
  # Fortuna has two NVMe drives. NixOS owns one (see _disk-config.nix); the other
  # is kept empty for a possible Windows 11 install. To keep that possible:
  #   - never put NixOS file systems, swap or data on the second drive
  #   - keep the firmware in UEFI-only mode (no CSM) with the TPM enabled
  #   - if Secure Boot is set up (lanzaboote), enroll keys with Microsoft's
  #     (`sbctl enroll-keys --microsoft`)
  #   - install Windows with the NixOS drive disconnected, so it creates its own ESP
  #
  # Installing (from the NixOS installer, booted with Secure Boot off):
  #   1. set the drive id in _disk-config.nix
  #   2. sudo nix run github:nix-community/disko -- --mode destroy,format,mount ./modules/hosts/fortuna/_disk-config.nix
  #   3. nixos-generate-config --no-filesystems --root /mnt, and replace
  #      _hardware-configuration.nix with /mnt/etc/nixos/hardware-configuration.nix
  #   4. copy the pre-generated SSH host key (the one `host_fortuna` in .sops.yaml
  #      is derived from) to /mnt/etc/ssh/, so sops-nix can decrypt alberth's password
  #   5. sudo nixos-install --no-root-passwd --flake .#fortuna (root stays locked:
  #      base sets users.mutableUsers = false, so a root password would not stick)
  den.aspects.fortuna = {
    includes = [
      den.aspects._1password
      den.aspects.amdgpu
      # Push what it builds (its own and magnus's remote builds) to the cache
      den.aspects.attic.push
      den.aspects.audio
      den.aspects.bluetooth
      den.aspects.browsers
      den.aspects.browsers.linux.helium
      den.aspects.certbot
      den.aspects.disko
      den.aspects.elgato
      den.aspects.fonts
      den.aspects.game-streaming
      den.aspects.ghostty
      den.aspects.noctalia
      den.aspects.openssh
      # magnus's first-choice Linux builder (x86_64, and aarch64 under QEMU)
      den.aspects.remote-build.server
      den.aspects.steam
      den.aspects.tailscale
      den.aspects.zed
    ];

    nixos = {
      # The leading `_` keeps import-tree from loading these as flake modules.
      imports = [
        ./_disk-config.nix
        ./_hardware-configuration.nix
      ];

      # Send audio to the GPU's HDMI output by default: WirePlumber picks the sink
      # with the highest priority.session, so raise it above the onboard codec's.
      services.pipewire.wireplumber.extraConfig."51-fortuna-hdmi-default" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "~alsa_output.*hdmi.*"; } ];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          }
        ];
      };

      networking.networkmanager.enable = true;
      users.users.alberth.extraGroups = [ "networkmanager" ];

      local.certbot = {
        email = "${certbotOwners}";
        fqdns = [
          "${hostName}.home.matos.cc"
          "${hostName}.ts.matos.cc"
        ];
      };

      system.stateVersion = "26.05";
    };
  };

  # alberth is the primary user on fortuna (system.primaryUser on macOS, wheel on NixOS),
  # reads mail (Fastmail in Thunderbird) and develops (language toolchains) here.
  den.aspects.fortuna.provides.alberth.includes = [
    den.batteries.primary-user
    den.aspects.alberth.dev
    den.aspects.alberth.mail
  ];
}
