{
  den.aspects.tex.macos.mactex = {
    homeManager = { pkgs, lib, ... }: {
      home.sessionPath = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "/Library/TeX/texbin" ];
    };

    darwin = {
      homebrew.casks = [
        "mactex"
      ];
    };
  };
}
