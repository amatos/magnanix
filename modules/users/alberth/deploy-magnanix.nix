# User:      alberth (den.aspects.alberth.deployMagnanix)
# Platforms: home-manager
# Purpose:   Installs ~/.local/bin/deploy-magnanix, which deploys `main` from the
#            live checkout (magnanix.repoDir) to the machine it runs on.
#
# Notes:
# - Steps: remember the current branch, check out `main`, `git pull
#   --ff-only`, run this host's nh wrapper with `switch` (shows the diff first),
#   then check the original branch back out, even after a failure or Ctrl-C.
# - Refuses to run with uncommitted changes on another branch, and stops with an
#   error if magnanix.repoDir is missing or isn't a git checkout.
# - A real executable rather than a shell alias, so it works over SSH
#   (`ssh <host> deploy-magnanix`). Deploy after CI passes on `main`.
{
  den.aspects.alberth.deployMagnanix = {
    includes = [
      # Needs the host, so the script switches the machine it runs on.
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
                  repo=${lib.escapeShellArg config.magnanix.repoDir}

                  # Fail with a clear message rather than a bare `cd` or git error.
                  # The second check catches a directory that exists but isn't the
                  # checkout, such as a stray tree created by another module.
                  if [ ! -d "$repo" ]; then
                    echo "deploy-magnanix: $repo does not exist; clone magnanix there or set magnanix.repoDir" >&2
                    exit 1
                  fi
                  if [ ! -e "$repo/.git" ]; then
                    echo "deploy-magnanix: $repo is not a git checkout; clone magnanix there or set magnanix.repoDir" >&2
                    exit 1
                  fi

                  cd "$repo"

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
            in
            {
              home.file.".local/bin/deploy-magnanix".source = lib.getExe deploy;
            };
        }
      )
    ];
  };
}
