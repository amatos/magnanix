# Aspect:    den.aspects.tex.texstudio (part of den.aspects.tex)
# Platforms: home-manager
# Purpose:   Installs TeXstudio, a cross-platform LaTeX editor.
{
  den.aspects.tex.texstudio = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.texstudio
      ];
    };
  };
}
