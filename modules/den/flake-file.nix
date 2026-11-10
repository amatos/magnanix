# Aspect:    none (flake-level module)
# Platforms: n/a
# Purpose:   Sets up flake-file, which generates flake.nix from the
#            flake-file.* options in ./modules: the flake description, the
#            outputs expression, and the nixpkgs, import-tree and flake-file
#            inputs. Never edit flake.nix by hand; run `nix run .#write-flake`.
{ inputs, ... }:
{
  # flake-file generates flake.nix from the `flake-file.*` options declared in
  # these modules. Inputs are declared next to the aspect that uses them; this
  # file holds only the ones that belong to the flake itself. After changing an
  # input, regenerate flake.nix and the lock with:
  #
  #   nix run .#write-flake
  #
  # `flakeModules.flake` is the variant for flakes without flake-parts. It adds a
  # top-level `outputs` option (see ../flake/outputs.nix).
  imports = [
    inputs.flake-file.flakeModules.flake
    # Keeps `follows` declarations in flake.nix up to date with `flake-edit follow`
    # (runs as part of write-flake and is verified by `nix flake check`). Opt an
    # input out with `flake-file.inputs.<name>.inputs.<dep>.autoFollow = false;`.
    inputs.flake-file.flakeModules.auto-follow
  ];

  flake-file = {
    description = "magnanix: nix-darwin, NixOS and Home Manager on Determinate Nix";

    inputs = {
      # flake-file generates flake.nix, so it has to be an input of it
      flake-file.url = "github:denful/flake-file";
      # Unstable Nixpkgs, straight from the nixpkgs-unstable channel branch so
      # the lock tracks Hydra-cached revisions without waiting on FlakeHub.
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      # Previously pulled from FlakeHub, which mirrors the same channel but can
      # lag behind it (that lag once pinned an atuin build that failed on Hydra,
      # so it had no cached binary). To switch back, use this URL instead
      # (0.1 = unstable, 0 = stable) and run `nix run .#write-flake`:
      #   nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
      # import-tree auto-loads every module under ./modules
      import-tree.url = "github:denful/import-tree";
    };

    # Evaluate every module under ./modules. Hosts, users and features are all
    # declared there as Den aspects; Den builds the system configurations. The
    # flake outputs themselves come from the `outputs` option.
    outputs = ''
      inputs:
      (inputs.nixpkgs.lib.evalModules {
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [ (inputs.import-tree ./modules) ];
      }).config.outputs
        inputs
    '';
  };
}
