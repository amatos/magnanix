# Ruby runtime and development tools.
{
  den.aspects.ruby = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          ruby # runtime, includes gem, bundler, irb and rake
          rubocop # linter and formatter
          ruby-lsp # language server (LSP)
        ];
      };
  };
}
