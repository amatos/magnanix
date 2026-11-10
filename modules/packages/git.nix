# Aspects:   den.aspects.git          (included by base)
#            den.aspects.git.signing  (opt-in, per user per host)
# Platforms: home-manager
# Purpose:   Git with modern defaults and tooling: git-lfs, delta (pager),
#            difftastic (`git difftool`), mergiraf (merge driver), lazygit,
#            git-absorb and git-extras. user.name and user.email come from the
#            user's meta (fullName, email).
#
# Notes (changes from git's defaults; details beside each setting):
# - New repos start on `main`; push sets the upstream on first push; fetch
#   prunes deleted branches and tags; rebase autostashes, applies fixup!
#   commits and moves stacked branches; rerere remembers conflict resolutions;
#   diffs use the histogram algorithm. `pull` keeps git's default.
# - merge.conflictStyle = diff3 is set by the mergiraf module, which needs it.
# - Home Manager won't enable delta's and difftastic's git integrations
#   together, so difftastic is wired up by hand as diff.tool.
# - Signing is a separate aspect because the GPG key (on a YubiKey) isn't
#   usable on every machine. Include it from a host's
#   `provides.<user>.includes` where it is.
{ den, ... }:
{
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
              column.ui = "auto"; # list branches/tags in columns when they fit
              branch.sort = "-committerdate"; # most recently used branches first
              tag.sort = "version:refname"; # v1.10 sorts after v1.9
              help.autocorrect = "prompt"; # offer to run the command a typo meant
              commit.verbose = true; # show the diff while writing the message

              diff = {
                algorithm = "histogram"; # cleaner hunks than the default (myers)
                colorMoved = "plain"; # moved lines get their own colour
                mnemonicPrefix = true; # i/w/c/h prefixes instead of a/b
                renames = true; # detect renames and copies
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
                followTags = true; # push annotated tags that point at pushed commits
              };
              rebase = {
                autoSquash = true; # applies fixup! commits (e.g. from git-absorb)
                autoStash = true;
                updateRefs = true; # move stacked branches along with a rebase
              };
              rerere = {
                enabled = true; # remember conflict resolutions
                autoupdate = true; # stage files rerere resolved
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
