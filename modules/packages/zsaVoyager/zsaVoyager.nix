# Aspect:    den.aspects.zsa.voyager
# Platforms: home-manager (through the aspects it includes)
# Purpose:   Tools for the ZSA Voyager keyboard: Keymapp and Zapp.
{ den, ... }: {
  den.aspects.zsa.voyager = {
    includes = [
      den.aspects.zsa.keymapp
      den.aspects.zsa.zapp
    ];
  };
}
