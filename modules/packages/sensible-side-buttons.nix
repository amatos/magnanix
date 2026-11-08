# SensibleSideButtons, which makes the mouse side buttons go back and forward
# in macOS apps. Packaged locally (pkgs/sensible-side-buttons.nix) because the
# nixpkgs version predates Apple silicon support. Only the `darwin` class
# installs anything. It needs Accessibility permission, granted by hand in
# System Settings > Privacy & Security > Accessibility the first time it runs.
{
  den.aspects.macos.sensibleSideButtons = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          (pkgs.callPackage ../../pkgs/sensible-side-buttons.nix { })
        ];
      };
  };
}
