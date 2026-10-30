{
  den.aspects.tex.texlab = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        texlab
      ];
    };
  };
}
