{ den, ... }: {
  den.aspects.tex = {
    includes = [
      den.aspects.tex.latexmk
      den.aspects.tex.macos.mactex
      den.aspects.tex.macos.texshop
      den.aspects.tex.macos.texstudio
      den.aspects.tex.texlab
    ];
  };
}
