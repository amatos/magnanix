# Aspect:    den.aspects.tex.macos.mactex (part of den.aspects.tex)
# Platforms: darwin, home-manager (macOS only)
# Purpose:   Installs the MacTeX TeX distribution as a Homebrew cask and puts
#            /Library/TeX/texbin (lualatex, latexmk, tlmgr, ...) on PATH.
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
