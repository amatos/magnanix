# Ruby runtime and development tools.
{
  den.aspects.ruby = {
    homeManager =
      { config, pkgs, ... }:
      let
        ruby = pkgs.ruby_4_0;
        # Gems built against the same interpreter as `ruby`.
        rubyPackages = pkgs.rubyPackages_4_0;
      in
      {
        # The Nix Ruby's own gem directory is read-only, so `gem install` and
        # `bundle install` fall back to the per-ABI user directory. Put its
        # executables on PATH.
        home.sessionPath = [ "${config.xdg.dataHome}/gem/ruby/${ruby.version.libDir}/bin" ];

        # Per-project Ruby versions, from `.ruby-version` or `mise.toml`. Outside
        # such a project the Nix Ruby below is used.
        programs.mise.enable = true;

        home.packages = [
          ruby # runtime, includes gem, bundler, irb, rake, debug and rbs
          rubyPackages.ruby-lsp # language server (LSP)
          pkgs.bundler-audit # vulnerability audit for Gemfile.lock

          # RuboCop and Standard run on nixpkgs' default Ruby: their dependency
          # unicode-emoji 4.1.0 declares `ruby < 4.0`, so the Ruby 4 builds fail
          # at startup. As standalone CLIs that doesn't matter; a project that
          # lists either in its Gemfile uses its own copy through ruby-lsp.
          pkgs.rubocop # linter and formatter
          pkgs.rubyPackages.standard # zero-config RuboCop wrapper
        ];
      };
  };
}
