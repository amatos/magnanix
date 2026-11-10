# Hosts:     nixostron-x86_64 and nixostron-aarch64 (both den.aspects.nixostron,
#            both with hostName "nixostron")
# Platform:  x86_64-linux / aarch64-linux (NixOS), a disposable headless VM
# Purpose:   Test bed for trying a change on NixOS before it lands. Add the
#            aspect under test to its includes on a branch, then run
#            `nixostron-vm test <branch>` from the dev shell. See
#            documentation/testing-vms.md.
#
# Notes:
# - Disk via disko: GPT, 1 GiB ESP at /boot, ext4 root on /dev/vda (virtio-blk
#   under both Tart and QEMU).
# - Only way in: SSH as `ephemeral` with the access key.
# - Bootstrap keys (host key, ephemeral's age key) are placed in
#   /var/lib/nixostron-keys by nixostron-vm and installed by the
#   `nixostron-keys` activation script before sops-nix runs, so the VM keeps
#   one identity however often it's rebuilt.
# - canTouchEfiVariables is forced off: a VM's NVRAM isn't worth writing, and
#   Tart resets it with each clone.
{ den, lib, ... }:
let
  hostName = "nixostron";
  user = "ephemeral";

  # Where nixostron-vm puts the bootstrap keys (secrets/bootstrap/nixostron.yaml)
  # before an activation: copied in by nixos-anywhere or over SSH on Tart, and
  # shared read-only from the host by QEMU. The `nixostron-keys` activation script
  # below installs them where sshd and sops-nix look. Never in a saved image.
  keyDir = "/var/lib/nixostron-keys";

  # QEMU settings shared by `build-vm` and disko's `vmWithDisko` (see nixostron-vm)
  qemuVm = {
    virtualisation = {
      graphics = false;
      cores = 4;
      memorySize = 8192;
      # nixostron-vm SSHes in through localhost:2222
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      # nixostron-vm exports NIXOSTRON_KEYS, a temporary directory holding the
      # decrypted keys. Mounted in the initrd, so it is there for activation.
      sharedDirectories.nixostron-keys = {
        source = "$NIXOSTRON_KEYS";
        target = keyDir;
      };
    };
  };
in
{
  # One Den host per architecture, both named nixostron on the network and both
  # configured by den.aspects.nixostron: x86_64 runs under QEMU on muninn and
  # fortuna, aarch64 under Tart on magnus. Den sets nixpkgs.hostPlatform from the
  # system key. See documentation/testing-vms.md.
  den.hosts = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
    "nixostron-${lib.head (lib.splitString "-" system)}" = {
      users.${user} = { };
      inherit hostName;
      aspect = den.aspects.nixostron;
    };
  });

  # Configuration shared by both nixostron hosts: a disposable, headless VM.
  den.aspects.nixostron = {
    includes = [ den.aspects.disko ];

    nixos =
      { modulesPath, pkgs, ... }:
      {
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

        system.stateVersion = "26.05";

        # Tart (Virtualization.framework) and QEMU both attach the disk as virtio-blk.
        disko.devices.disk.main = {
          type = "disk";
          device = "/dev/vda";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };

        # A VM has no NVRAM worth writing to, and Tart's is reset with each clone.
        boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

        # Headless: SSH with ephemeral's key is the only way in.
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        # Checked by nixostron-vm to prove system secrets decrypt.
        sops.secrets.canary = { };

        # Install the bootstrap keys, if present, before sops-nix decrypts anything.
        system.activationScripts.nixostron-keys = lib.stringAfter [ "users" "groups" ] ''
          if [ -f ${keyDir}/host_key ]; then
            ${pkgs.coreutils}/bin/install -D -m 600 -o root -g root ${keyDir}/host_key /etc/ssh/ssh_host_ed25519_key
            ${pkgs.coreutils}/bin/install -D -m 644 -o root -g root ${keyDir}/host_key_pub /etc/ssh/ssh_host_ed25519_key.pub
          fi
          if [ -f ${keyDir}/user_key ]; then
            home=/home/${user}
            ${pkgs.coreutils}/bin/install -d -m 700 -o ${user} -g users "$home/.config" "$home/.config/sops-nix"
            ${pkgs.coreutils}/bin/install -m 600 -o ${user} -g users ${keyDir}/user_key "$home/.config/sops-nix/key.txt"
          fi
        '';
        system.activationScripts.setupSecrets.deps = [ "nixostron-keys" ];

        virtualisation.vmVariant = qemuVm;
        virtualisation.vmVariantWithDisko = qemuVm;
      };
  };

  # ephemeral is the primary user on nixostron (system.primaryUser on macOS, wheel on NixOS).
  den.aspects.nixostron.provides.${user} = {
    includes = [ den.batteries.primary-user ];

    # Checked by nixostron-vm to prove Home Manager secrets decrypt.
    homeManager.sops.secrets.canary = { };
  };
}
