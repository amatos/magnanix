# Aspect:    den.aspects.determinate (added to every host via den.default.includes)
# Platforms: nixos, darwin
# Purpose:   Hands the Nix installation to Determinate Nix and writes the
#            settings every host shares to /etc/nix/nix.custom.conf.
#
# Notes:
# - On macOS Determinate owns Nix, so nix-darwin's nix.* options are switched
#   off: never use nix.gc, nix.optimise or nix.settings in a darwin block. Use
#   determinateNix.customSettings and
#   determinateNix.determinateNixd.garbageCollector.strategy instead.
# - Put a setting in `sharedSettings` if every host should have it, or straight
#   in the darwin/nixos block if only one platform should.
{ den, inputs, ... }:
let
  # Determinate Nix settings shared by every host. nix-darwin takes them as
  # `determinateNix.customSettings`; NixOS takes them as `nix.settings`.
  sharedSettings = {
    # Enables parallel evaluation (remove this setting or set the value to 1 to disable)
    eval-cores = 0;
    extra-experimental-features = [
      "build-time-fetch-tree" # Enables build-time flake inputs
    ];
  };
in
{
  # Determinate Nix: the upstream module, plus this flake's own settings.
  den.aspects.determinate = {
    darwin = {
      imports = [ inputs.determinate.darwinModules.default ];

      determinateNix = {
        # Enable Determinate to handle the Nix configuration (nix-darwin's own Nix
        # management is switched off). This is the module's default, but being
        # explicit keeps it that way if the default ever changes.
        enable = true;

        # Custom Determinate Nix settings, written to /etc/nix/nix.custom.conf
        customSettings = sharedSettings;
      };
    };

    nixos = {
      imports = [ inputs.determinate.nixosModules.default ];

      # Unlike nix-darwin, the NixOS module has no `customSettings` option. It takes
      # the ordinary `nix.settings` and moves the generated nix.conf to
      # /etc/nix/nix.custom.conf, which Determinate Nixd's own nix.conf includes.
      nix.settings = sharedSettings;
    };
  };

  # Determinate 3.* module
  flake-file.inputs.determinate = {
    url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    inputs.nixpkgs.follows = "nixpkgs";
    # Keep the nixpkgs that Determinate's own `nix` input pins. Making it follow
    # ours (what auto-follow would do) changed the nixostron closure.
    inputs.nix.inputs.nixpkgs.autoFollow = false;
  };

  den.default.includes = [ den.aspects.determinate ];
}
