{ inputs, ... }:
{
  # Brings in the `den` module argument and all `den.*` options. This works
  # without flake-parts, since flake.nix evaluates the modules itself.
  imports = [ inputs.den.flakeModule ];

  # Den is an aspect-oriented Nix framework: write features, not host files
  flake-file.inputs.den.url = "github:denful/den";
}
