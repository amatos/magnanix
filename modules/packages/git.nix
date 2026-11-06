{ den, ... }:
{
  # Git with modern defaults and tooling, via Home Manager.
  den.aspects.git = {
    homeManager =
      { config, pkgs, ... }:
      let
        # Identity comes from the user aspect's meta (see modules/users/*), when set.
        meta = (den.aspects.${config.home.username} or { }).meta or { };
      in
      {
        programs = {
          git = {
            enable = true;
            lfs.enable = true; # large files tracked as pointers

            ignores = [
              ".DS_Store"
              ".direnv/"
              "result"
              "result-*"
            ];

            settings = {
              user =
                (if meta ? fullName then { name = meta.fullName; } else { })
                // (if meta ? email then { inherit (meta) email; } else { });

              init.defaultBranch = "main";
              column.ui = "auto";
              branch.sort = "-committerdate";
              tag.sort = "version:refname";
              help.autocorrect = "prompt";
              commit.verbose = true; # show the diff while writing the message

              diff = {
                algorithm = "histogram";
                colorMoved = "plain";
                mnemonicPrefix = true;
                renames = true;
                # Structural (syntax-aware) diffs on demand: `git difftool`. Wired up
                # here because Home Manager's difftastic git integration excludes delta's.
                tool = "difftastic";
              };
              # merge.conflictStyle is set to diff3 by the mergiraf module, which needs it.

              difftool = {
                prompt = false;
                difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
              };
              pager.difftool = true;

              fetch = {
                prune = true;
                pruneTags = true;
              };
              push = {
                autoSetupRemote = true; # no more `--set-upstream origin <branch>`
                followTags = true;
              };
              rebase = {
                autoSquash = true; # applies fixup! commits (e.g. from git-absorb)
                autoStash = true;
                updateRefs = true; # move stacked branches along with a rebase
              };
              rerere = {
                enabled = true; # remember conflict resolutions
                autoupdate = true;
              };
            };
          };

          # Syntax-highlighted pager for diff, log, show and blame.
          delta = {
            enable = true;
            enableGitIntegration = true;
            options = {
              navigate = true; # n / N jump between files
              line-numbers = true;
            };
          };

          difftastic.enable = true;

          # Syntax-aware merge driver; falls back to line-based merging when unsure.
          mergiraf = {
            enable = true;
            enableGitIntegration = true;
          };

          # Terminal UI for staging hunks, rebasing and browsing history.
          lazygit = {
            enable = true;
            settings.git.pagers = [ { pager = "delta --paging=never"; } ];
          };
        };

        home.packages = with pkgs; [
          git-absorb # `git absorb`: turn staged changes into fixup! commits
          git-extras # git-summary, git-ignore, git-undo and friends (zsh plugin has completions)
        ];
      };

    # Signs commits and tags with the user's GPG key (meta.gpgKey). Include it only
    # where that key is usable, e.g. from a host's `provides.<user>.includes`.
    signing.homeManager =
      { config, ... }:
      let
        meta = (den.aspects.${config.home.username} or { }).meta or { };
      in
      {
        programs.git.signing = {
          format = "openpgp";
          key = meta.gpgKey;
          signByDefault = true;
        };
      };
  };
}
