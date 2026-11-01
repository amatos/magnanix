{
  den.aspects.tex.texstudio = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.texstudio
      ];
    };
  };
}
