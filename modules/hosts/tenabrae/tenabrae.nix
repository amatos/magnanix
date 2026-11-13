# Host:      tenabrae (den.aspects.tenabrae)
# Platform:  aarch64-linux (NixOS), Raspberry Pi Zero 2 W (512 MB RAM)
# Purpose:   Pi-hole for the LAN and the tailnet, with Quad9 over DNS-over-TLS
#            upstream. On Wi-Fi (SSID vox) with a DHCP reservation on the router;
#            SSH (keys only) and Tailscale.
#
# Notes:
# - Boots from an SD image built from this config (sdImage below): Pi firmware
#   -> U-Boot -> extlinux, root on ext4 labelled NIXOS_SD, grown to fill the
#   card on first boot. No UEFI, so base's systemd-boot is replaced.
# - Too small to evaluate its own flake: build elsewhere and copy the result
#   in. CI's aarch64-linux job builds it into the Attic cache. Install and
#   deploy steps are in documentation/tenabrae.md. It is deliberately not in
#   update-all-magnanix's default hosts.
# - Host key: generated off-host (`host_tenabrae` in .sops.yaml; the private
#   half is in 1Password). Before first boot, copy it onto the card's FAT
#   partition as ssh_host_ed25519_key; the `tenabrae-host-key` activation script
#   moves it to /etc/ssh and deletes it from the card before sops-nix runs.
#   A key copied there later replaces the installed one at the next boot.
# - Secrets (secrets/hosts/tenabrae.yaml): `wireless_env` (psk_vox=<passphrase>)
#   and `pihole_env` (see modules/packages/pihole.nix).
# - Interface names are the kernel's (wlan0), not predictable names, so the
#   firewall rules can name the Wi-Fi interface.
{ den, lib, ... }:
let
  hostName = "tenabrae";
  firmwareMount = "/boot/firmware";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
in
{
  # Den sets nixpkgs.hostPlatform from this key.
  den.hosts.aarch64-linux.tenabrae = {
    users.alberth = { };
    inherit hostName;
  };

  den.aspects.tenabrae = {
    includes = [
      den.aspects.openssh
      den.aspects.pihole
      den.aspects.tailscale
    ];

    nixos =
      {
        config,
        modulesPath,
        pkgs,
        ...
      }:
      {
        # Builds config.system.build.sdImage, and declares the card's file systems
        # (NIXOS_SD at /, the FAT firmware partition at /boot/firmware).
        imports = [ (modulesPath + "/installer/sd-card/sd-image.nix") ];

        system.stateVersion = "26.05";

        # --- Boot ---------------------------------------------------------------

        # No UEFI on a Pi: the firmware starts U-Boot, which reads extlinux.conf.
        boot.loader = {
          systemd-boot.enable = lib.mkForce false;
          efi.canTouchEfiVariables = lib.mkForce false;
          grub.enable = false;
          generic-extlinux-compatible.enable = true;
        };

        # Headless, and every MB counts: no splash, no firmware daemon (the Pi's
        # firmware isn't on LVFS), and /tmp on the card rather than in RAM.
        boot.plymouth.enable = lib.mkForce false;
        services.fwupd.enable = lib.mkForce false;
        boot.tmp.useTmpfs = lib.mkForce false;

        # Mini UART (ttyS1 under the mainline kernel) and HDMI, for when Wi-Fi fails.
        boot.kernelParams = [
          "console=ttyS1,115200n8"
          "console=tty0"
        ];

        image.baseName = "${hostName}-sd-image";
        sdImage = {
          populateFirmwareCommands =
            let
              # The Zero 2 W only; the generic aarch64 image's config.txt also
              # covers the Pi 4 and 5.
              configTxt = pkgs.writeText "config.txt" ''
                [all]
                kernel=u-boot.bin
                arm_64bit=1
                # U-Boot needs the UART enabled, used or not.
                enable_uart=1
                # Otherwise the serial console is garbled.
                core_freq=250
                # Keep the firmware from drawing over the kernel's framebuffer.
                avoid_warnings=1
                # Headless: give the GPU the minimum and Linux the rest of the 512 MB.
                gpu_mem=16
              '';
            in
            ''
              (cd ${pkgs.raspberrypifw}/share/raspberrypi/boot && cp bootcode.bin fixup*.dat start*.elf bcm2710-rpi-zero-2-w.dtb $NIX_BUILD_TOP/firmware/)
              cp ${pkgs.ubootRaspberryPiAarch64}/u-boot.bin firmware/u-boot.bin
              cp ${configTxt} firmware/config.txt
            '';
          populateRootCommands = ''
            mkdir -p ./files/boot
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
          '';
        };

        # Mount the firmware partition in the initrd, so the host key copied onto
        # it is readable during activation, which runs there (chrooted into
        # /sysroot, before switch-root). sd-image declares it `nofail noauto`,
        # so the list is replaced with mkForce, which also drops the
        # `x-initrd.mount` NixOS adds for neededForBoot; it's restored by hand.
        # Not `nofail`: systemd wouldn't order the mount before initrd-fs.target,
        # so activation could still run first. The partition is on the boot
        # card, so it's always there. (tenabrae's first boot mounted it only
        # after switch-root, and activation never saw the key.)
        fileSystems.${firmwareMount} = {
          options = lib.mkForce [
            "x-initrd.mount"
            "umask=0077"
          ];
          neededForBoot = true;
        };

        # Install the host key from the card before sops-nix needs it. A key on
        # the card always wins, replacing whatever /etc/ssh holds (e.g. one sshd
        # generated on a boot that missed it), so copying a key there is also how
        # to replace it. Removes it from the card afterwards, along with the
        # AppleDouble (`._*`) files macOS leaves next to it.
        system.activationScripts.tenabrae-host-key = lib.stringAfter [ "specialfs" ] ''
          src=${firmwareMount}/ssh_host_ed25519_key
          if [ -f "$src" ]; then
            echo "tenabrae-host-key: installing the host key from ${firmwareMount}" >&2
            ${pkgs.coreutils}/bin/install -D -m 600 -o root -g root "$src" ${hostKey}
            ${pkgs.openssh}/bin/ssh-keygen -y -f ${hostKey} > ${hostKey}.pub
            ${pkgs.coreutils}/bin/chmod 644 ${hostKey}.pub
            ${pkgs.coreutils}/bin/rm -f "$src" "$src.pub" ${firmwareMount}/._ssh_host_ed25519_key*
          elif [ ! -d ${firmwareMount} ] || ! ${pkgs.util-linux}/bin/mountpoint -q ${firmwareMount}; then
            echo "tenabrae-host-key: ${firmwareMount} is not mounted; can't check for a host key" >&2
          fi
        '';
        system.activationScripts.setupSecretsForUsers.deps = [ "tenabrae-host-key" ];
        system.activationScripts.setupSecrets.deps = [ "tenabrae-host-key" ];

        # --- Memory -------------------------------------------------------------

        # 512 MB: compressed swap in RAM first, then a file on the card for the
        # occasional spike (switching generations, Home Manager activation).
        zramSwap.enable = true;
        swapDevices = [
          {
            device = "/var/lib/swapfile";
            size = 1024;
          }
        ];

        # --- Network ------------------------------------------------------------

        # Keeps the Wi-Fi interface at wlan0.
        networking.usePredictableInterfaceNames = false;

        # Wi-Fi (Broadcom 43436s; its firmware comes from sd-image's all-hardware).
        # The router reserves this host's address.
        sops.secrets.wireless_env = { };
        networking.wireless = {
          enable = true;
          secretsFile = config.sops.secrets.wireless_env.path;
          networks.vox.pskRaw = "ext:psk_vox";
        };

        # No RTC: the clock starts wherever timesyncd last saved it, and Unbound's
        # DoT can't validate certificates until it's right. Name lookups may go
        # through Pi-hole -> Unbound, so list NTP servers by address (Cloudflare's
        # time.cloudflare.com) ahead of the names.
        networking.timeServers = [
          "162.159.200.1"
          "162.159.200.123"
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
        ];

        local.pihole.interfaces = [
          "wlan0"
          "tailscale0"
        ];
      };
  };

  # alberth is the primary user on tenabrae (wheel on NixOS).
  den.aspects.tenabrae.provides.alberth.includes = [ den.batteries.primary-user ];
}
