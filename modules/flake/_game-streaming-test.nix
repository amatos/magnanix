# A NixOS VM test for den.aspects.game-streaming (the `game-streaming` check,
# Linux only). The leading `_` keeps import-tree from loading it as a flake
# module; outputs.nix imports it.
#
# It boots a VM with the aspect's NixOS module and no Steam, then, as alberth:
# starts a Big Picture session with `game-session`, checks that Sway and
# Sunshine come up and that Sunshine listens, stops it, and does the same for a
# desktop session (`--desktop`). The VM has no GPU, so it covers the session and
# its plumbing, not VAAPI encoding or an actual stream.
{
  pkgs,
  # den.aspects.game-streaming.nixos, the aspect's NixOS module
  gameStreaming,
}:
let
  user = "alberth";
  # The first normal user's UID
  uid = 1000;
in
pkgs.testers.runNixOSTest {
  name = "game-streaming";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ gameStreaming ];

      # For checking Sunshine's web UI
      environment.systemPackages = [ pkgs.curl ];

      local.game-streaming.steam = false;

      # What the aspect's per-user include sets on a real host
      users.users.${user} = {
        isNormalUser = true;
        linger = true;
        extraGroups = [
          "input"
          "uinput"
        ];
      };

      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };
    };

  testScript = ''
    # game-session talks to alberth's systemd manager, as it would over SSH.
    def as_user(command):
        return (
            "su ${user} -c 'XDG_RUNTIME_DIR=/run/user/${toString uid} "
            + "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString uid}/bus "
            + command
            + "'"
        )

    machine.wait_for_unit("multi-user.target")

    with subtest("alberth lingers, so their systemd manager runs without a login"):
        machine.wait_for_unit("user@${toString uid}.service")

    with subtest("Sunshine's streaming ports are open on tailscale0 only"):
        rules = machine.succeed("iptables -S nixos-fw")
        assert "-i tailscale0 -p tcp -m tcp --dport 47989 " in rules, rules
        assert "--dport 47990 " not in rules, rules

    with subtest("game-session rejects a malformed mode"):
        machine.fail(as_user("game-session start 1080p"))

    with subtest("game-session start runs Sway and Sunshine"):
        out = machine.succeed(as_user("game-session start 1280x720"))
        assert "started bigpicture at 1280x720@60Hz" in out, out
        machine.wait_for_unit("game-session.service", "${user}")
        machine.wait_until_succeeds("pgrep -u ${user} -x sway", timeout=60)
        machine.wait_until_succeeds("pgrep -u ${user} sunshine", timeout=60)
        machine.succeed("grep -qx 'output HEADLESS-1 mode 1280x720@60Hz' /run/user/${toString uid}/game-session/sway.conf")

    with subtest("Sunshine listens, and its web UI answers"):
        machine.wait_for_open_port(47989)
        machine.wait_for_open_port(47990)
        machine.wait_until_succeeds("curl -fsk -o /dev/null https://localhost:47990/", timeout=60)

    with subtest("a second start is a no-op"):
        out = machine.succeed(as_user("game-session start"))
        assert "already running" in out, out

    with subtest("status and logs work"):
        machine.succeed(as_user("game-session status"))
        machine.succeed(as_user("game-session logs"))

    with subtest("game-session stop ends the session"):
        machine.succeed(as_user("game-session stop"))
        machine.wait_until_fails("pgrep -u ${user} -x sway", timeout=60)
        machine.wait_until_fails("pgrep -u ${user} sunshine", timeout=60)
        machine.wait_for_closed_port(47989)

    with subtest("game-session start --desktop runs the desktop session"):
        out = machine.succeed(as_user("game-session start --desktop"))
        assert "started desktop at 1920x1080@60Hz" in out, out
        machine.wait_until_succeeds("pgrep -u ${user} -x sway", timeout=60)
        machine.succeed("grep -q 'include .*-game-session-desktop.conf' /run/user/${toString uid}/game-session/sway.conf")
        machine.wait_for_open_port(47989)
        machine.succeed(as_user("game-session stop"))
        machine.wait_until_fails("pgrep -u ${user} -x sway", timeout=60)
  '';
}
