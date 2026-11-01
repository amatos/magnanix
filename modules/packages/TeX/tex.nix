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
