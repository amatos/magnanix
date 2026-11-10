# Aspect:    den.aspects.fonts
# Platforms: home-manager
# Purpose:   Programming and terminal fonts (Ioskeley Mono variants, JetBrains
#            Mono, Hack, Inconsolata, Nerd Font variants, Font Awesome, ...).
#
# Notes:
# - Fonts come from nixpkgs. Only use a Homebrew cask (homebrew.casks in a
#   darwin block) for a font nixpkgs doesn't package.
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
