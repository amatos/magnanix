# Aspect:    den.aspects.cli.imagemagick (included by base)
# Platforms: home-manager
# Purpose:   ImageMagick (`magick`), for converting and editing images on the
#            command line.
{
  den.aspects.cli.imagemagick = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.imagemagick
      ];
    };
  };
}
