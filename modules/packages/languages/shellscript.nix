# Shell script (bash, sh, zsh) development tools. Named `shellscript` because
# `shell` is the aspect for the login shells themselves.
{
  den.aspects.shellscript = {
    homeManager =
      { pkgs, ... }:
      {
        # Neovim also has shfmt on its own PATH (see neovim.nix); these are for
        # the shell and other editors.
        home.packages = with pkgs; [
          shellcheck # linter
          shfmt # formatter
          bash-language-server # language server (LSP), runs shellcheck and shfmt
        ];
      };
  };
}
