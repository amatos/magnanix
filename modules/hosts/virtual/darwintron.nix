{ den, inputs, ... }:
{
  den.hosts.aarch64-darwin.darwintron = {
    users.ephemeral = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to darwintron, a disposable Tart VM on magnus. See
  # "Testing changes on darwintron" in the README.
  den.aspects.darwintron = {
    darwin =
      { lib, ... }:
      {
        system.stateVersion = 7;

        # An OS update would reboot the VM mid-test and change what is being tested.
        system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = lib.mkForce false;

        # Checked by darwintron-vm to prove system secrets decrypt.
        sops.secrets.canary = { };
      };
  };

  # ephemeral is the primary user on darwintron (system.primaryUser on macOS, wheel on NixOS).
  den.aspects.darwintron.provides.ephemeral = {
    includes = [ den.batteries.primary-user ];

    # Checked by darwintron-vm to prove Home Manager secrets decrypt.
    homeManager.sops.secrets.canary = { };
  };
}
