# Aspect:    none (flake input only)
# Platforms: darwin
# Purpose:   Declares the nix-darwin input that Den builds macOS hosts with and
#            the dev shell takes darwin-rebuild from.
{ ... }:
let
  versions = import ./_versions.nix;
in
{
  # nix-darwin; the branch is set in ./_versions.nix. Hosts build with
  # `inputs.nix-darwin.lib.darwinSystem` and the dev shell uses its darwin-rebuild.
  flake-file.inputs.nix-darwin = {
    url = "github:nix-darwin/nix-darwin/${versions.nix-darwin}";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
