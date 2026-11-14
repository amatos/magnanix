# tenabrae: Pi-hole on a Raspberry Pi Zero 2 W

`tenabrae` (`modules/hosts/tenabrae/tenabrae.nix`) is a Raspberry Pi Zero 2 W running Pi-hole (`den.aspects.pihole`,
`modules/packages/pihole.nix`) for the LAN and the tailnet.

- **DNS path:** client → pihole-FTL (:53) → Unbound (127.0.0.1:5335) → Quad9 over DNS-over-TLS (port 853).
- **DHCP:** stays on the router. Give tenabrae a DHCP reservation there, then point the router's DHCP DNS option
  at that address.
- **Network:** Wi-Fi only (`wlan0`), on `voxdev`, a 2.4 GHz WPA2-only network; see [Wi-Fi](#wi-fi). DNS and
  the dashboard (`http://tenabrae/admin`) are open on `wlan0` and `tailscale0` only.

## Why it isn't installed like the other hosts

With 512 MB of RAM, nixos-anywhere's kexec installer can't run, and the Pi can't evaluate this flake or build
its own closures. So:

- **Install:** flash an SD image built from tenabrae's own configuration.
- **Updates:** build elsewhere, then have the Pi fetch the result from Attic and switch to it. There are two
  places to build:
  - **From magnus:** a plain `nix build` goes to the [remote builders](remote-builders.md) (fortuna, then
    muninn, under QEMU), whose `attic watch-store` pushes the result to Attic.
  - **CI:** the `ubuntu-24.04-arm` runner builds tenabrae on every push to `main` and pushes it to Attic.

`deploy-magnanix` and `update-all-magnanix` won't work on tenabrae. It's left out of the latter's default
host list.

## Secrets

`secrets/hosts/tenabrae.yaml` (edit with `sops secrets/hosts/tenabrae.yaml` from the dev shell):

| Key            | Value                                                          |
| -------------- | -------------------------------------------------------------- |
| `wireless_env` | `psk_voxdev=<passphrase>`, bare (no quotes or trailing spaces) |
| `pihole_env`   | `FTLCONF_webserver_api_password=<dashboard password>`          |

The host decrypts these, and `alberth_password` from `secrets/common.yaml`, with its SSH host key. That key was
generated off-host. Its age recipient is `host_tenabrae` in `.sops.yaml`, and the private half is kept in
1Password.

## Installing

1. Make sure tenabrae can decrypt `common.yaml`: run `sops updatekeys secrets/common.yaml`, and commit the
   result. `grep -c "recipient: age1" secrets/common.yaml` should count tenabrae's key too. Without it,
   `alberth_password` fails to decrypt and you can't log in.
2. On fortuna, from a checkout of this repo at the commit you want, build the image. fortuna builds aarch64
   under QEMU itself, and anything already in Attic is downloaded instead of built. (To use CI's build instead,
   run the **CI/CD Build** workflow manually with **tenabrae-sd-image** ticked, then add `--max-jobs 0`, which
   only downloads.)

   ```sh
   nix build --out-link ~/tenabrae-image -L \
     .#nixosConfigurations.tenabrae.config.system.build.sdImage
   ```

3. Insert the card and find it. `dd` overwrites whatever disk you name, so check that the size and model match
   the card before going on:

   ```sh
   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
   ```

4. Flash it, with `sdX` being the card (the whole disk, not a partition):

   ```sh
   sudo umount /dev/sdX?* 2>/dev/null
   nix shell nixpkgs#zstd -c sh -c \
     'zstd -dc ~/tenabrae-image/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress'
   sudo blockdev --rereadpt /dev/sdX
   ```

5. Install the host key into the card's root file system. With the key from 1Password saved as
   `ssh_host_ed25519_key`:

   ```sh
   sudo mount /dev/disk/by-label/NIXOS_SD /mnt
   sudo install -D -m 600 -o root -g root ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
   sudo ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key   # should match host_tenabrae's key
   sudo umount /mnt && sync
   ```

   Then delete the local copy (`shred -u ssh_host_ed25519_key`) and pull the card. sops-nix decrypts with this
   key during activation, so the Pi needs it from the first boot on.
6. Boot the Pi. It joins `voxdev`, expands the root partition to fill the card, and starts sshd and Pi-hole.
   Check with `ssh alberth@tenabrae`, then run `sudo tailscale up` once.
7. On the router: reserve tenabrae's address, and hand it out as the DNS server.

If Wi-Fi never comes up, put the card back in fortuna and read the Pi's journal:
`sudo mount -o ro /dev/disk/by-label/NIXOS_SD /mnt`, then `sudo journalctl -D /mnt/var/log/journal -b 0` (`-b 0`
is the last boot it recorded; check `--list-boots`). Without the
host key, sops can't decrypt the Wi-Fi passphrase (or alberth's password), so the Pi can't connect and you can't
log in at the console. Look for `sops-install-secrets` errors, and check that
`/mnt/etc/ssh/ssh_host_ed25519_key` is the key from 1Password (`ssh-keygen -y -f` on it should print
`host_tenabrae`'s public key). If sshd generated its own key on a boot that lacked it, reinstall the right one
the same way.

The Pi's activity LED shows how far it got: a steady double-pulse heartbeat means Linux is running, and a
repeating group of flashes is a firmware error code. The serial console is on the GPIO UART (`ttyS1`, 115200
baud, a 3.3 V USB-TTL adapter on pins 8 and 10), and there is a console on mini-HDMI.

## Wi-Fi

The Zero 2 W's chip (BCM43436s, `brcmfmac` driver) is 2.4 GHz 802.11n only, and its firmware handles
WPA2/WPA3 routers badly. What the configuration does about it:

- **WPA2 only** (`authProtocols = [ "WPA-PSK" ]`). NixOS's default also offers SAE (WPA3) and fast
  transition. On a WPA2/WPA3 network wpa_supplicant then picks SAE, and authentication times out.
- **`brcmfmac feature_disable=0x82000`** turns off the firmware's own WPA handshake (FWSUP) and SAE, so
  wpa_supplicant does the handshake. With them on, every association fails with `status_code=16`, which
  brcmfmac reports for any failed connection.
- **`voxdev`**: a separate 2.4 GHz, WPA2-only (AES) SSID on the router, the only network configured. The chip
  can't use 5 GHz, and on `vox` (WPA2/WPA3) it associated but failed the 4-way handshake.
- **Firmware:** only what the chip loads (the Raspberry Pi package's 43436s firmware and nvram, linux-firmware's
  `brcmfmac43430-sdio.clm_blob`, and the regulatory database), instead of the ~825 MiB of firmware sd-image's
  all-hardware brings in.
- **`wireless_env` is owned by `wpa_supplicant`**, the user the service runs as; it reads the file itself.

On the Pi, `iw` isn't installed and wpa_supplicant has no control socket, so `wpa_cli` doesn't work. Use
`ip -br addr show wlan0`, and `sudo journalctl -u wpa_supplicant` for the connection log.

## Deploying a change

From magnus, build the change (on the remote builders, or fetch CI's build with `--max-jobs 0`), then have the
Pi switch to it:

```sh
path=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.tenabrae.config.system.build.toplevel)
ssh -t alberth@tenabrae "sudo nix-store --realise $path \
  && sudo nix-env --profile /nix/var/nix/profiles/system --set $path \
  && sudo $path/bin/switch-to-configuration switch"
```

The Pi downloads the closure from Attic itself; nothing is copied through magnus. If you built it just now,
give the builder's `attic watch-store` a moment to finish pushing before you run the `ssh` line.

## Clock and DoT

The Pi has no real-time clock. Unbound can't validate Quad9's certificate until the clock is right, and the
Pi's own name lookups may go through Pi-hole. So the NTP servers are listed by IP address: the LAN's own,
muninn's, first (`10.0.4.129`, reserved on the router), then time.cloudflare.com (`162.159.200.1` and
`162.159.200.123`), with the NixOS pool names as a last resort. timesyncd also restores the
last saved time at boot. The router (`10.0.4.1`) doesn't answer NTP requests. See [NTP](ntp.md).
