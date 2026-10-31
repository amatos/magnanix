{
  den.aspects.tex.macos.texstudio = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.texstudio
      ];
    };
  };
}
