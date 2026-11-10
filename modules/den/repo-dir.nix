# Aspect:    none (added to every user via den.default.homeManager)
# Platforms: home-manager
# Purpose:   Declares magnanix.repoDir, the path of the live, writable checkout
#            of this repo (default ~/Developer/magnanix). Out-of-store symlinks
#            (such as Zed's settings.json) and deploy-magnanix use it.
{
  # Where the live (writable) checkout of this repo lives. Modules that symlink
  # tracked config files out of the store (mkOutOfStoreSymlink) read this, so the
  # location is declared in exactly one place. Override per user/host with
  # `magnanix.repoDir = "/some/path";` in a homeManager module.
  den.default.homeManager =
    { config, lib, ... }:
    {
      options.magnanix.repoDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Developer/magnanix";
        defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Developer/magnanix"'';
        description = "Absolute path of the live checkout of this repo.";
      };
    };
}
