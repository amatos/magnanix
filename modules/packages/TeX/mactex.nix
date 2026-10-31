{
  den.aspects.tex.macos.mactex = { pkgs, lib, ... }: {
    homeManager = {
      home.sessionPath = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "/Library/TeX/texbin" ];
    };

    darwin = {
      homebrew.casks = [
        "mactex"
      ];
    };
  };
}
