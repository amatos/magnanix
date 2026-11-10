# Aspect:    den.aspects.zig
# Platforms: home-manager
# Purpose:   Zig and zls (its language server), kept on the same release
#            because zls only supports the Zig version it was built for.
{
  den.aspects.zig = {
    homeManager =
      { pkgs, ... }:
      {
        # zls only supports the Zig release it was built for, so keep the two on
        # the same version (nixpkgs' defaults are; pin both together if not).
        home.packages = with pkgs; [
          zig # compiler, build system and formatter (zig fmt)
          zls # language server (LSP)
        ];
      };
  };
}
