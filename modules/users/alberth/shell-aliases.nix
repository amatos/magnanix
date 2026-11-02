{
  # alberth's own aliases, for bash, zsh and fish.
  den.aspects.alberth.shellAliases = {
    includes = [
      # Needs the host, so the deploy alias switches the machine it runs on.
      (
        { host, ... }:
        {
          homeManager =
            { config, lib, ... }:
            let
              # Fast-forwards the live checkout and switches this host to it with its nh
              # wrapper, which shows the diff before switching. The wrapper builds `.#...`,
              # so this runs in the checkout; `sh -c` leaves the shell's own directory
              # alone and behaves the same under bash, zsh and fish.
              deploy = lib.concatStringsSep " && " [
                "cd ${lib.escapeShellArg config.magnanix.repoDir}"
                "git pull --ff-only"
                "nix run .#${host.name} -- switch"
              ];

              aliases = {
                deploy-magnanix = "sh -c ${lib.escapeShellArg deploy}";
              };
            in
            {
              programs = {
                bash.shellAliases = aliases;
                fish.shellAliases = aliases;
                zsh.shellAliases = aliases;
              };
            };
        }
      )
    ];
  };
}
