{
  den.aspects.ghostty = {
    homeManager = { pkgs, ... }: {
      # The `ghostty` package doesn't build on macOS; `ghostty-bin` is the upstream app bundle.
      home.packages = [
        (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty)
      ];
    };
  };
}
