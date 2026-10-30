{ den, ... }: {
  den.aspects.tex = {
    includes = [
      den.aspects.tex.latexmk
      den.aspects.tex.mactex
      den.aspects.tex.texlab
      den.aspects.tex.texshop
      den.aspects.tex.texstudio
    ];
  };
}
