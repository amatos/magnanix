# Aspect:    den.aspects.shell.shellAliases (included by each shell aspect)
# Platforms: home-manager, nixos, darwin
# Purpose:   Aliases shared by the shells.
#
# Notes:
# - zsh and fish (Home Manager): rm/mv/cp ask before overwriting or deleting
#   (-i), ssh* variants (sshk: skip host key check, sshv: verbose, sshp: force
#   password, ssht: 5 s timeout, sshx: X11 forwarding, sshnone: no known_hosts
#   at all), and git-log / git-author history views.
# - System-wide (every shell): `clipboard` / `paste`, backed by xclip on NixOS
#   (which also gets pbcopy/pbpaste lookalikes) and pbcopy/pbpaste on macOS.
{
  den.aspects.shell.shellAliases = {
    homeManager =
      { ... }:
      let
        commonAliases = {
          # Safety prompts
          rm = "rm -i";
          mv = "mv -i";
          cp = "cp -i";

          # SSH variants
          sshk = "ssh -o StrictHostKeyChecking=no";
          sshv = "ssh -vvv";
          sshp = "ssh -o PreferredAuthentications=password";
          ssht = "ssh -o ConnectTimeout=5";
          sshx = "ssh -X";
          sshnone = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";

          # Git history viewers
          git-log = "git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          git-author = "echo '👤 Commit Author History:' && git log --pretty=format:'%h%x09%an%x09%ad%x09%s'";
        };
      in
      {
        programs = {
          fish.shellAliases = commonAliases;
          zsh.shellAliases = commonAliases;
        };
      };

    nixos = {
      environment.shellAliases = {
        clipboard = "xclip -selection clipboard -i";
        paste = "xclip -selection clipboard -o";
        pbcopy = "xclip -selection clipboard";
        pbpaste = "xclip -selection clipboard -o";
      };
    };

    darwin = {
      environment.shellAliases = {
        clipboard = "pbcopy";
        paste = "pbpaste";
      };
    };
  };
}
