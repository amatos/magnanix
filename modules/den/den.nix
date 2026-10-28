{ inputs, ... }:
{
  # Brings in the `den` module argument and all `den.*` options. This works
  # without flake-parts, since flake.nix evaluates the modules itself.
  imports = [ inputs.den.flakeModule ];
}
