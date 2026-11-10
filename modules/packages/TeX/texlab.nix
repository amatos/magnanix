# Aspect:    den.aspects.tex.texlab (part of den.aspects.tex)
# Platforms: home-manager
# Purpose:   Installs texlab, the LaTeX language server used by editors.
{
  den.aspects.tex.texlab = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        texlab
      ];
    };
  };
}
