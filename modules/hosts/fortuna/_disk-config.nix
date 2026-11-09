# Fortuna's NixOS drive, partitioned by disko at install time:
#
#   ESP   1 GiB   vfat, /boot (systemd-boot)
#   luks  rest    LUKS2 "cryptroot", holding one btrfs filesystem with the
#                 subvolumes /, /home, /nix and /swap (a swapfile)
#
# Fortuna has a second NVMe drive, reserved for a possible Windows 11 install.
# It is deliberately NOT declared here: disko wipes every disk it declares, so
# listing it would destroy Windows. Keep NixOS (including /home and swap) off it.
#
# Refer to the drive by its /dev/disk/by-id path, never /dev/nvme0n1 or
# /dev/nvme1n1: the kernel can number the two drives differently between boots.
let
  # TODO: replace with the NixOS drive's id, from `ls -l /dev/disk/by-id/` in the
  # installer (the nvme-<model>_<serial> entry without a -partN suffix).
  device = "/dev/disk/by-id/nvme-CHANGE_ME";

  btrfsOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.nixos = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        # 1 GiB leaves room for several kernels and initrds. Windows gets its own
        # ESP on its own drive (install it with this drive disconnected).
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

        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # The passphrase is asked for interactively when disko formats the disk.
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = btrfsOptions;
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsOptions;
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOptions;
                };
                "/swap" = {
                  mountpoint = "/.swapvol";
                  # Fortuna has 128 GiB of RAM, so swap is only a safety net
                  # against running out of memory. Hibernation is not supported:
                  # it would need a swapfile at least as large as RAM.
                  swap.swapfile.size = "16G";
                };
              };
            };
          };
        };
      };
    };
  };
}
