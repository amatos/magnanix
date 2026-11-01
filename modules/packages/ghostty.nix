{
  den.aspects.ghostty = {
    # Lets hosts that don't run Ghostty still serve SSH sessions coming from it.
    terminfo = {
      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty.terminfo ];
      };

      darwin = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty-bin.terminfo ];
      };
    };

    homeManager = { pkgs, ... }: {
      # The `ghostty` package doesn't build on macOS; `ghostty-bin` is the upstream app bundle.
      home.packages = [
        (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty)
      ];
    };
  };
}
