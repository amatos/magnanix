# Aspect:    den.aspects.tex
# Platforms: home-manager, darwin (through the aspects it includes)
# Purpose:   The LaTeX bundle: latexmk config, MacTeX and TeXShop (macOS only),
#            TeXstudio, the texlab language server and Texpile. Include this
#            rather than the individual tex.* aspects.
{ den, ... }: {
  den.aspects.tex = {
    includes = [
      den.aspects.tex.latexmk
      den.aspects.tex.macos.mactex
      den.aspects.tex.macos.texshop
      den.aspects.tex.texstudio
      den.aspects.tex.texlab
      den.aspects.tex.texpile
    ];
  };
}
