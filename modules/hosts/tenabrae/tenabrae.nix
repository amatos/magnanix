# Host:      tenabrae (den.aspects.tenabrae)
# Platform:  aarch64-linux (NixOS), Raspberry Pi Zero 2 W (512 MB RAM)
# Purpose:   Pi-hole for the LAN and the tailnet, with Quad9 over DNS-over-TLS
#            upstream. On Wi-Fi (SSID voxdev, else vox) with a DHCP reservation
#            on the router; SSH (keys only) and Tailscale.
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
#   half is in 1Password). Before first boot, install it into the card's root
#   file system (NIXOS_SD) at /etc/ssh/ssh_host_ed25519_key from a Linux
#   machine; see documentation/tenabrae.md. sops-nix decrypts with it during
#   activation, so without it there's no Wi-Fi and no password.
# - Secrets (secrets/hosts/tenabrae.yaml): `wireless_env` (psk_voxdev= and
#   psk_vox= lines) and `pihole_env` (see modules/packages/pihole.nix).
# - Interface names are the kernel's (wlan0), not predictable names, so the
#   firewall rules can name the Wi-Fi interface.
{ den, lib, ... }:
let
  hostName = "tenabrae";
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
        # Turn off the firmware's own WPA handshake (FWSUP, 0x2000) and SAE
        # (0x80000), so wpa_supplicant does the handshake itself. With them on,
        # the firmware fails every association with a WPA2/WPA3 router
        # (status 16, "authentication timed out").
        boot.extraModprobeConfig = ''
          options brcmfmac feature_disable=0x82000
        '';
        # wpa_supplicant runs as its own user and reads the file itself.
        sops.secrets.wireless_env.owner = config.systemd.services.wpa_supplicant.serviceConfig.User;
        # voxdev: a 2.4 GHz, WPA2-only network for this host, preferred. vox
        # (WPA2/WPA3) is the fallback. The router reserves this host's address.
        # WPA2 only on both: the default list also offers SAE (WPA3) and fast
        # transition, which this chip's firmware can't do.
        networking.wireless = {
          enable = true;
          secretsFile = config.sops.secrets.wireless_env.path;
          networks = {
            voxdev = {
              pskRaw = "ext:psk_voxdev";
              authProtocols = [ "WPA-PSK" ];
              priority = 10;
            };
            vox = {
              pskRaw = "ext:psk_vox";
              authProtocols = [ "WPA-PSK" ];
            };
          };
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
