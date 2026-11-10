# Aspect:    den.aspects.imagemagick (included by base)
# Platforms: home-manager
# Purpose:   ImageMagick (`magick`), for converting and editing images on the
#            command line.
{
  den.aspects.imagemagick = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.imagemagick
      ];
    };
  };
}
