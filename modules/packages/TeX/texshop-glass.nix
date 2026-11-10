# Aspect:    den.aspects.tex.macos.texshop (part of den.aspects.tex)
# Platforms: darwin
# Purpose:   Installs TeXShop (the Liquid Glass build), a macOS LaTeX editor.
#
# Notes:
# - Not in nixpkgs, and the mactex cask doesn't include this build, so the signed .pkg
#   is fetched from CTAN and run through /usr/sbin/installer after activation.
# - Only reinstalls when pkgutil reports a different version than
#   `texshopVersion`. To update, bump the version and the sha256.
{
  den.aspects.tex.macos.texshop = {
    darwin =
      { pkgs, ... }:
      let
        # Not packaged in nixpkgs, and this exact build isn't in the
        # homebrew-cask "mactex" version either, so fetch and install
        # the signed/notarized .pkg directly.
        # source: https://www.tug.org/mactex/gui-link.html
        texshopVersion = "2026";
        texshopPkg = pkgs.fetchurl {
          url = "https://mirror.ctan.org/systems/mac/mactex/TeXShopLiquidGlass.pkg";
          sha256 = "1pkrgy52jmcrff6frl9hz7ywnr7l6k4ywry1svzma2pbf92jlp57";
        };
      in
      {
        system.activationScripts.postActivation.text = ''
          installedTeXShopVersion=$(/usr/sbin/pkgutil --pkg-info org.tug.mactex.texshopliquidglass 2>/dev/null | awk '/^version:/ {print $2}') || true
          if [ "$installedTeXShopVersion" != "${texshopVersion}" ]; then
            echo "installing TeXShop (Liquid Glass) ${texshopVersion}..." >&2
            /usr/sbin/installer -pkg ${texshopPkg} -target /
          fi
        '';
      };
  };
}
