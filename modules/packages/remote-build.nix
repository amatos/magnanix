# Aspects:   den.aspects.remote-build.server (opt-in, NixOS hosts that build for others)
#            den.aspects.remote-build.client (opt-in, hosts that send builds out)
# Platforms: server: nixos
#            client: darwin
# Purpose:   Lets magnus build Linux derivations, so a plain
#            `nix build .#nixosConfigurations.<linux host>...` works on the Mac:
#            - x86_64-linux on fortuna (first choice), then muninn
#            - aarch64-linux on magnus itself, with Determinate's Native Linux
#              Builder (a short-lived VM per build, nothing left running)
#
# Notes:
# - Transport: magnus's nix-daemon connects over SSH (ssh-ng) as `nix-ssh`, a
#   system user whose only command is `nix-daemon --stdio` (nix.sshServe). It is
#   a trusted Nix user, so it can build, but it has no shell and no other access.
#   Only the key in `clientKeys` may log in as it.
# - Client key: /etc/nix/builder_ed25519 on magnus (root-only, the path the
#   Determinate module uses). Generated off-host and installed by hand; see
#   documentation/remote-builders.md.
# - Builders' host keys are pinned below (publicHostKey), so root on magnus
#   needs no known_hosts entry. They are the same keys the hosts decrypt sops
#   secrets with; re-pin here if one is ever replaced.
# - Native Linux Builder: needs magnus logged in to FlakeHub (a free account,
#   `sudo determinate-nixd login`). It registers itself as an external builder
#   for aarch64-linux (native) and x86_64-linux (Rosetta). Nix prefers a
#   reachable remote builder over building locally, so the remote builders list
#   only x86_64-linux: aarch64 stays on magnus, and x86_64 goes to fortuna or
#   muninn, falling back to Rosetta on magnus only when neither answers.
# - Each build VM gets 1 CPU (Determinate's advice) and `nativeBuilderMemory`;
#   several builds at once means several VMs, so it's kept below the 8 GiB
#   default to leave magnus usable.
# - Builders fetch dependencies from the caches themselves
#   (builders-use-substitutes) rather than through magnus. What they build is
#   pushed to Attic by their own attic.push watcher.
# - An unreachable builder is skipped (fortuna off or in Windows), so muninn
#   takes the build.
let
  # magnus's nix-daemon key (the public half of /etc/nix/builder_ed25519).
  clientKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLYdwZLvOBZLI8qD2s/JGhAjC4mMd5r0MEEtqnaJqvq root@magnus nix builder"
  ];

  # Memory for each Native Linux Builder VM: 4 GiB.
  nativeBuilderMemory = 4 * 1024 * 1024 * 1024;

  # Remote x86_64-linux builders, fastest first. Reached by their LAN names. publicHostKey is the
  # base64 of the host's /etc/ssh/ssh_host_ed25519_key.pub line
  # (`printf %s "ssh-ed25519 AAAA..." | base64`), the form /etc/nix/machines takes.
  builders = [
    {
      hostName = "fortuna.home.matos.cc";
      # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFsOjzSAXwa4AZFoumRkmXhY3k4+ni9Mj9rKoJ6brW+
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhGc09qelNBWHdhNEFaRm91bVJrbVhoWTNrNCtuaTlNajlyS29KNmJyVys=";
      maxJobs = 8;
      speedFactor = 4;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
    {
      hostName = "muninn.home.matos.cc";
      # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDnw8CzTXukohE1iQu3LBAJlpAxJWGCLfOpRcWWK8Frg
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSURudzhDelRYdWtvaEUxaVF1M0xCQUpscEF4SldHQ0xmT3BSY1dXSzhGcmc=";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
  ];
in
{
  # A NixOS host that accepts builds for its own system from the client key.
  den.aspects.remote-build.server = {
    nixos.nix.sshServe = {
      enable = true;
      protocol = "ssh-ng";
      write = true;
      trusted = true;
      keys = clientKeys;
    };
  };

  # A Mac that builds aarch64-linux itself and sends x86_64-linux to the
  # builders above.
  den.aspects.remote-build.client = {
    darwin = {
      determinateNix = {
        determinateNixd.builder = {
          state = "enabled";
          memoryBytes = nativeBuilderMemory;
        };

        distributedBuilds = true;
        buildMachines = map (b: {
          inherit (b)
            hostName
            maxJobs
            publicHostKey
            speedFactor
            supportedFeatures
            ;
          protocol = "ssh-ng";
          sshUser = "nix-ssh";
          sshKey = "/etc/nix/builder_ed25519";
          # Not aarch64-linux: that stays on the Native Linux Builder (see the header).
          systems = [ "x86_64-linux" ];
        }) builders;
        customSettings.builders-use-substitutes = true;
      };
    };
  };
}
