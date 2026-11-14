# NTP

Every host sets its clock from the network's own NTP server, muninn, using `den.aspects.ntp.client`
(`modules/packages/ntp.nix`), which `base` includes. muninn runs the server, `den.aspects.ntp.server`, and gets its
own time from the public NixOS pool (see [The server](#the-server)). The router (`10.0.4.1`) doesn't answer NTP
requests, so nothing uses it.

- **Server:** `muninn.home.matos.cc`, or `muninn.ts.matos.cc` on hosts that include `den.aspects.tailscale`. The
  `tailscale` aspect makes the switch by setting `local.ntp.serverHost`, only as a default, so a host can set its
  own.
- **Fallback:** when muninn can't be reached (muninn down, or away from home without Tailscale), clients fall back
  to public servers.
- **NixOS** uses systemd-timesyncd. `networking.timeServers` lists `local.ntp.serverHost` first, then
  `local.ntp.upstreamServers` (the NixOS pool by default). timesyncd uses one server at a time and moves down the
  list when one stops answering.
- **macOS:** nix-darwin has no time server option, so each switch writes `/etc/ntp.conf` (the file System Settings >
  General > Date & Time edits) with muninn first and `time.apple.com` second, and restarts `timed` when the file
  changes.
- **tenabrae** sets `local.ntp.serverHost` to muninn's address, `10.0.4.129`, because its own name lookups go
  through its Pi-hole, whose DNS-over-TLS needs the clock to be right first. The router reserves that address for
  muninn; if it changes, change tenabrae too. tenabrae's fallbacks start with time.cloudflare.com, also by
  address. See [tenabrae](tenabrae.md#clock-and-dot).

To check a client: `timedatectl timesync-status` on NixOS, `sntp muninn.home.matos.cc` on macOS.

## The server

`den.aspects.ntp.server` runs chrony on the host:

- **Syncs** from `local.ntp.upstreamServers` (the NixOS pool), not from `networking.timeServers`, which the client
  aspect puts the host itself at the top of. chrony turns timesyncd off.
- **Answers** the LAN (`10.0.4.0/22`) and the tailnet (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`), the same clients
  as the [mail relay](mail.md#the-relay).
- **Opens** UDP port 123 only on the interfaces in `local.ntp.server.interfaces`, set in the server host's file.
  On muninn those are `enp0s31f6` (the LAN) and `tailscale0`.

To check it on muninn: `chronyc tracking` shows whether it's in sync, and `chronyc clients` lists the hosts asking
it for the time.
