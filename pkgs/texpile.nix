# When Texpile releases a new version:
#   1. Find the latest version at https://dl.texpile.com/latest.json
#   2. Run: nix store prefetch-file --hash-type sha256 https://dl.texpile.com/vX.Y.Z/Texpile-X.Y.Z.dmg
#      and:  nix store prefetch-file --hash-type sha256 https://dl.texpile.com/vX.Y.Z/Texpile-X.Y.Z.AppImage
#   3. Replace `version` and both hashes below with the new values.
#   4. Run `darwin-rebuild switch` / `nixos-rebuild switch` to install the new version.
{
  lib,
  stdenvNoCC,
  fetchurl,
  appimageTools,
}:

let
  pname = "texpile";
  version = "1.6.2";
  baseUrl = "https://dl.texpile.com/v${version}";

  meta = {
    description = "Free offline editor for LaTeX and Typst";
    homepage = "https://texpile.com";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    license = lib.licenses.agpl3Only;
    mainProgram = "texpile";
  };

  darwin = stdenvNoCC.mkDerivation {
    inherit pname version meta;

    src = fetchurl {
      url = "${baseUrl}/Texpile-${version}.dmg";
      hash = "sha256-Ij+FtahJpMsEa+f5rHv6E+qwaBvm8eBZrNYrN0o01Fc=";
    };

    # hdiutil needs to mount a disk image; the Nix sandbox blocks that on Darwin.
    __noChroot = true;

    # Disable fixup to prevent shebang patching from breaking the code signature.
    dontFixup = true;

    unpackPhase = ''
      mnt=$(mktemp -d)
      /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$src"
      /usr/bin/ditto "$mnt/Texpile.app" Texpile.app
      /usr/bin/hdiutil detach "$mnt"
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      /usr/bin/ditto Texpile.app "$out/Applications/Texpile.app"
      runHook postInstall
    '';
  };

  linux = appimageTools.wrapType2 {
    inherit pname version meta;

    src = fetchurl {
      url = "${baseUrl}/Texpile-${version}.AppImage";
      hash = "sha256-3OCMbDAqcNZvSKQXAD52yshlFGq4IF1r9asJndTMbPE=";
    };
  };
in
if stdenvNoCC.hostPlatform.isDarwin then darwin else linux
