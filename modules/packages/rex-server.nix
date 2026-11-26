# Aspect:    den.aspects.rex-server (included by base)
# Platforms: home-manager (Linux only; a no-op on macOS)
# Purpose:   The Rex (superlogical.com) server, from Rex's upstream prebuilt
#            flake: a personal Rex server per user, run as a systemd user
#            service. The Rex client is installed by hand, not here.
#
# Notes:
# - The flake tracks the preview channel (stable has no releases yet). Update
#   with `nix flake update rex`; flake.lock pins the exact release.
# - macOS: the Rex app runs the server there, and the upstream module refuses
#   services.rex on Darwin, so this aspect sets nothing on Macs.
# - The server needs the `rex` binary, terminfo and ssh guard, so enabling it
#   also turns on the module's programs.rex.
# - The service starts at login and stops at logout. To keep it running while
#   logged out, run `loginctl enable-linger` once as that user.
# - The ssh guard (stops TERM=xterm-rex reaching hosts that lack it) goes
#   through programs.ssh, so it is only on for users who enable programs.ssh.
{ inputs, ... }:
{
  flake-file.inputs.rex = {
    url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.rex-server = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = [ inputs.rex.homeManagerModules.default ];

        config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          services.rex.enable = true;

          # Avoids the module's warning for users without programs.ssh.
          programs.rex.sshGuard = lib.mkDefault config.programs.ssh.enable;
        };
      };
  };
}
