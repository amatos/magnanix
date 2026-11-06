{
  # alberth's own aliases, for bash, zsh and fish.
  den.aspects.alberth.shellAliases = {
    includes = [
      # Needs the host, so the deploy alias switches the machine it runs on.
      (
        { host, ... }:
        {
          homeManager =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              # Deploys `main` from the live checkout, whatever branch is checked out:
              # it remembers the current branch (or commit, if detached), checks out
              # `main`, fast-forwards it and switches this host with its nh wrapper,
              # which shows the diff before switching. The wrapper builds `.#...`, so
              # this runs in the checkout. On exit, even after a failure or Ctrl-C, it
              # checks the original branch back out.
              deploy = pkgs.writeShellApplication {
                name = "deploy-magnanix";
                runtimeInputs = [ pkgs.git ];
                text = ''
                  cd ${lib.escapeShellArg config.magnanix.repoDir}

                  original=$(git symbolic-ref --short -q HEAD || git rev-parse HEAD)

                  if [ "$original" != main ]; then
                    # Uncommitted changes would either block the checkout or be carried
                    # onto main and deployed with it.
                    if ! git diff --quiet HEAD; then
                      echo "deploy-magnanix: uncommitted changes on $original; commit or stash them first" >&2
                      exit 1
                    fi

                    restore() {
                      current=$(git symbolic-ref --short -q HEAD || git rev-parse HEAD)
                      if [ "$current" != "$original" ]; then
                        echo "deploy-magnanix: switching back to $original" >&2
                        git checkout --quiet "$original"
                      fi
                    }
                    trap restore EXIT

                    echo "deploy-magnanix: switching from $original to main" >&2
                    git checkout --quiet main
                  fi

                  git pull --ff-only
                  nix run .#${host.name} -- switch
                '';
              };

              aliases = {
                deploy-magnanix = lib.getExe deploy;
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
