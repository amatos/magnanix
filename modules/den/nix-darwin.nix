# Aspect:    none (flake input only)
# Platforms: darwin
# Purpose:   Declares the nix-darwin input that Den builds macOS hosts with and
#            the dev shell takes darwin-rebuild from.
{ ... }:
{
  # Unstable nix-darwin (master; use 0 for stable). Hosts build with
  # `inputs.nix-darwin.lib.darwinSystem` and the dev shell uses its darwin-rebuild.
  flake-file.inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
