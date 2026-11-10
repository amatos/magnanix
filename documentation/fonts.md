# Fonts


`den.aspects.fonts` (`modules/packages/fonts.nix`) installs fonts through Home Manager's `home.packages`. Every
font is currently installed from nixpkgs, and nixpkgs is the preferred source for fonts. Use a Homebrew cask
(`homebrew.casks` in the aspect's `darwin` class) only for a font with no Nix package. Casks should be the
exception, not the rule.
