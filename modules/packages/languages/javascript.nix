# Aspect:    den.aspects.javascript
# Platforms: home-manager
# Purpose:   Node.js LTS (programs.npm), pnpm, Bun, Deno, TypeScript 5,
#            typescript-language-server and Biome.
#
# Notes:
# - Global installs go to writable dirs on PATH: `npm install -g` to ~/.npm
#   (npm prefix in ~/.npmrc), `pnpm add -g` to PNPM_HOME, Bun and Deno to
#   ~/.bun/bin and ~/.deno/bin.
# - TypeScript 5, not nixpkgs' default 7: 7 no longer ships the tsserver.js
#   that typescript-language-server falls back to.
# - Biome is temporarily skipped on Linux (see the comment below).
{
  den.aspects.javascript = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
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

        home.packages =
          with pkgs;
          [
            deno # runtime with built-in formatter, linter and LSP

            # TypeScript 5 rather than nixpkgs' default 7: 7 is the native (Go) compiler
            # and no longer ships tsserver.js, which typescript-language-server needs
            # when a project has no TypeScript of its own in node_modules.
            typescript_5 # tsc and tsserver
            typescript-language-server # language server (LSP)
          ]
          # Linter and formatter for JS, TS, JSON and CSS.
          # TEMPORARY: skipped on Linux because Hydra has no x86_64-linux build of
          # biome 2.6.5 (cancelled on trunk), so Linux hosts compiled it from source for
          # hours and then failed. Remove the condition once cache.nixos.org has it.
          ++ lib.optional (!stdenv.hostPlatform.isLinux) biome;
      };
  };
}
