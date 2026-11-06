# Lua runtime and development tools.
{
  den.aspects.lua = {
    homeManager =
      { pkgs, ... }:
      {
        # Neovim also has lua-language-server and stylua on its own PATH (see
        # neovim.nix); these are for the shell and other editors.
        home.packages = with pkgs; [
          # LuaJIT (Lua 5.1 with extensions), the Lua that Neovim embeds. It also
          # provides `lua`, so a separate PUC Lua would collide.
          luajit
          luarocks # package manager
          lua-language-server # language server (LSP)
          stylua # formatter
        ];
      };
  };
}
