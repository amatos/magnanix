# Game streaming

`den.aspects.game-streaming` (`modules/packages/game-streaming.nix`) streams Steam games from fortuna to magnus
without anyone logging in at fortuna. Fortuna runs [Sunshine](https://github.com/LizardByte/Sunshine) and Steam in a
headless Sway session; magnus connects with [Moonlight](https://moonlight-stream.org) over Tailscale.

## Everyday use

```sh
ssh fortuna game-session start              # 1920x1080@60
ssh fortuna game-session start 2560x1440@60 # or another mode
```

Open Moonlight on magnus, pick fortuna and start **Desktop**. Steam is already up in Big Picture mode.

```sh
ssh fortuna game-session stop     # ends Sway, Sunshine and Steam
ssh fortuna game-session status   # systemctl status of the session
ssh fortuna game-session logs     # its last 100 journal lines
```

To change the resolution, stop the session and start it again with the new mode.

Steam runs only one instance per user. If it's running in the Hyprland desktop session, `start` refuses until you
quit it there.

## First-time setup

1. Apply the configuration on fortuna and on magnus (magnus gets the Moonlight cask). Log out of fortuna's desktop
   session once, or reboot, so the new `input`/`uinput` group membership takes effect.
2. Start a session: `ssh fortuna game-session start`.
3. Open Sunshine's web UI through an SSH tunnel (it isn't open on the network):

   ```sh
   ssh -L 47990:localhost:47990 fortuna
   ```

   Browse to <https://localhost:47990>, accept the self-signed certificate and create the web UI username and
   password.
4. In Moonlight on magnus, add fortuna by its Tailscale name or IP if it isn't listed, and click it.
   Moonlight shows a PIN; enter it on the web UI's **PIN** page.
5. Start **Desktop** in Moonlight and sign in to Steam, including the Steam Guard check. Steam remembers the login,
   so later sessions start signed in.

Sunshine's credentials, paired clients and `apps.json` live in `~/.config/sunshine` on fortuna. Its settings come from
the aspect, so the web UI can't change them; edit `sunshineConfig` in the aspect instead.

## How it works

- `game-session` is a systemd user service. alberth lingers on fortuna, so it keeps running after SSH disconnects.
- Sway runs with `WLR_BACKENDS=headless,libinput`: a virtual `HEADLESS-1` output, and libinput for the virtual
  keyboard, mouse and gamepads Sunshine creates through `/dev/uinput`. Over SSH there's no logind seat, so
  `LIBSEAT_BACKEND=noop` makes libinput open the devices directly; that's why alberth is in `input` and `uinput`.
- Sunshine captures the output through wlr-screencopy and encodes with VAAPI on the Radeon.
- Every window is made fullscreen, so games and launchers fill the stream.
- Sunshine's streaming ports are open on `tailscale0` only.

## Troubleshooting

Start with `game-session logs`.

- **Sway exits with a libinput or seat error:** check that `id` lists `input` and `uinput` and that
  `loginctl show-user alberth -p Linger` says `Linger=yes`. New groups only apply to new logins, so log out of the
  desktop session and reconnect over SSH after the first switch.
- **Sunshine reports no display or no encoder:** its log lines in the journal say whether wlr capture or VAAPI failed.
- **Moonlight can't connect:** run `tailscale ping fortuna` from magnus. The streaming ports are open only on
  `tailscale0`, so fortuna's LAN address won't work.
- **`start` says Steam is already running:** quit Steam in the Hyprland session first.

## Caveats

- A keyboard or mouse plugged into fortuna also reaches the game session, and while the Hyprland session is logged in,
  Sunshine's virtual input reaches Hyprland too.
- Membership of `input` lets anything running as alberth read every input device on fortuna.
- NixOS's own `sunshine.service` is installed but not started; the game session runs Sunshine itself.
