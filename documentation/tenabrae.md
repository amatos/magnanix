# tenabrae: Pi-hole on a Raspberry Pi Zero 2 W

`tenabrae` (`modules/hosts/tenabrae/tenabrae.nix`) is a Raspberry Pi Zero 2 W running Pi-hole (`den.aspects.pihole`,
`modules/packages/pihole.nix`) for the LAN and the tailnet.

- **DNS path:** client → pihole-FTL (:53) → Unbound (127.0.0.1:5335) → Quad9 over DNS-over-TLS (port 853).
- **DHCP:** stays on the router. Give tenabrae a DHCP reservation there, then point the router's DHCP DNS option
  at that address.
- **Network:** Wi-Fi only (SSID `vox`, interface `wlan0`). DNS and the dashboard (`http://tenabrae/admin`) are
  open on `wlan0` and `tailscale0` only.

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

| Key            | Value                                                       |
| -------------- | ----------------------------------------------------------- |
| `wireless_env` | `psk_vox=<Wi-Fi passphrase>`                                |
| `pihole_env`   | `FTLCONF_webserver_api_password=<dashboard password>`       |

The host decrypts these, and `alberth_password` from `secrets/common.yaml`, with its SSH host key. That key was
generated off-host. Its age recipient is `host_tenabrae` in `.sops.yaml`, and the private half is kept in
1Password.

## Installing

1. Make sure tenabrae can decrypt `common.yaml`: `sops updatekeys secrets/common.yaml` (it is listed there).
2. Build the image on magnus. The remote builders do the work, and anything already in Attic is downloaded
   instead of built:

   ```sh
   nix build --out-link tenabrae-image -L \
     .#nixosConfigurations.tenabrae.config.system.build.sdImage
   ```

3. Or, without the builders, run the **CI/CD Build** workflow manually with **tenabrae-sd-image** ticked, then
   run the same command with `--max-jobs 0`, which only downloads and never builds.

4. Flash it (find the card with `diskutil list`, and double-check the disk number, because `dd` overwrites
   whatever disk you name):

   ```sh
   diskutil unmountDisk /dev/diskN
   zstd -dc tenabrae-image/sd-image/*.img.zst | sudo dd of=/dev/rdiskN bs=4m status=progress
   ```

5. The card's FAT partition mounts as `/Volumes/FIRMWARE`. Copy the host key onto it from 1Password, saving it as
   `ssh_host_ed25519_key`, then `diskutil eject /dev/diskN`. On first boot, the `tenabrae-host-key` activation
   script moves the key to `/etc/ssh/` and deletes it from the card, before sops-nix runs.
6. Boot the Pi. It joins `vox`, expands the root partition to fill the card, and starts sshd and Pi-hole.
   Check with `ssh alberth@tenabrae`, then run `sudo tailscale up` once.
7. On the router: reserve tenabrae's address, and hand it out as the DNS server.

If Wi-Fi never comes up, check `/Volumes/FIRMWARE` with the card back in magnus first. If
`ssh_host_ed25519_key` is still there, the Pi never installed it. Without the host key, sops can't decrypt the
Wi-Fi passphrase (or alberth's password), so the Pi can't connect and you can't log in at the console. If the
key is gone, the problem is Wi-Fi itself. Read the Pi's journal from the card on a Linux machine:
`mount -o ro /dev/disk/by-label/NIXOS_SD /mnt`, then `journalctl -D /mnt/var/log/journal -b -1`. A key copied
onto the card always replaces the installed one at the next boot, so recopying it is safe.

The serial console is on the GPIO UART (`ttyS1`, 115200 baud), and there is a console on
mini-HDMI.

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
Pi's own name lookups may go through Pi-hole. So the NTP servers are listed by IP address first
(time.cloudflare.com, `162.159.200.1` and `162.159.200.123`), and timesyncd restores the last saved time at
boot.
