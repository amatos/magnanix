{
  den.aspects.fonts = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        ioskeley-mono.standard
        ioskeley-mono.nf
        ioskeley-mono.nl
        ioskeley-mono.nl-nf
        ioskeley-mono.term
        ioskeley-mono.term-nf
        anonymousPro
        font-awesome
        hack-font
        inconsolata
        jetbrains-mono
        liberation_ttf
        nerd-fonts.dejavu-sans-mono
        nerd-fonts.hack
        nerd-fonts.inconsolata-go
        nerd-fonts.jetbrains-mono
      ];
    };
  };
}
