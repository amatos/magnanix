# JavaScript / TypeScript runtimes and development tools.
{
  den.aspects.javascript = {
    homeManager =
      { config, pkgs, ... }:
      {
        # Installs Node.js (current LTS) and writes ~/.npmrc. The Nix Node's own
        # prefix is read-only, so `npm install -g` goes to ~/.npm instead.
        programs.npm = {
          enable = true;
          package = pkgs.nodejs;
          settings.prefix = "${config.home.homeDirectory}/.npm";
        };

        # Installs pnpm and sets PNPM_HOME, whose bin holds `pnpm add -g` binaries.
        programs.pnpm.enable = true;

        # Installs Bun (runtime, bundler, test runner and package manager).
        programs.bun.enable = true;

        # Binaries installed globally by npm, Bun and Deno.
        home.sessionPath = [
          "${config.home.homeDirectory}/.npm/bin"
          "${config.home.homeDirectory}/.bun/bin"
          "${config.home.homeDirectory}/.deno/bin"
        ];

        home.packages = with pkgs; [
          deno # runtime with built-in formatter, linter and LSP

          # TypeScript 5 rather than nixpkgs' default 7: 7 is the native (Go) compiler
          # and no longer ships tsserver.js, which typescript-language-server needs
          # when a project has no TypeScript of its own in node_modules.
          typescript_5 # tsc and tsserver
          typescript-language-server # language server (LSP)
          biome # linter and formatter for JS, TS, JSON and CSS
        ];
      };
  };
}
