# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "magnanix: nix-darwin, NixOS and Home Manager on Determinate Nix";

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      specialArgs = {
        inherit inputs;
        inherit (inputs) self;
      };
      modules = [ (inputs.import-tree ./modules) ];
    }).config.outputs
      inputs;

  inputs = {
    delta = {
      url = "github:zed-industries/delta-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    den = {
      url = "github:denful/den";
    };
    determinate = {
      url = "github:DeterminateSystems/determinate/main";
      inputs = {
        nix.inputs.git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file = {
      url = "github:denful/flake-file";
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree = {
      url = "github:denful/import-tree";
    };
    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
