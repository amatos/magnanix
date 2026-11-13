# Aspect:    none (plain data, not a module; import-tree skips `_` files)
# Platforms: n/a
# Purpose:   The branch or tag each core flake input tracks, in one place so
#            they can be moved between unstable and stable together.
#
# Notes:
# - Read with `import ./_versions.nix`. The input declarations themselves
#   (follows, autoFollow, comments) stay next to the aspect that uses them.
# - nixpkgs, home-manager and nix-darwin must be on matching releases. To go
#   stable, switch all three at once, e.g. "nixos-26.05", "release-26.05" and
#   "nix-darwin-26.05".
# - After changing a value, run `nix run .#write-flake`.
# - This is not the place for stateVersion: that is set per host and user
#   at install time and should not change on upgrades.
{
  # github:NixOS/nixpkgs (stable: "nixos-YY.MM" or "nixpkgs-YY.MM-darwin")
  nixpkgs = "nixpkgs-unstable";

  # github:nix-community/home-manager (stable: "release-YY.MM")
  home-manager = "master";

  # github:nix-darwin/nix-darwin (stable: "nix-darwin-YY.MM")
  nix-darwin = "master";

  # github:DeterminateSystems/determinate, which also sets the Nix version
  # (pin a release with a tag, e.g. "v3.24.2")
  determinate = "main";
}
