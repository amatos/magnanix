{
  den.aspects.fonts = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        # ioskeley-mono.normal-NF
        # ioskeley-mono.normal-NL-NF
        # ioskeley-mono.normal
        # ioskeley-mono.condensed
        # ioskeley-mono.normal-term
        # ioskeley-mono.condensed-NF
        # ioskeley-mono.semiCondensed
        # ioskeley-mono.normal-term-NF
        # ioskeley-mono.condensed-term
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

    darwin = {
      homebrew.casks = [ "font-ioskeley-mono" ];
    };

  };
}
