# nixpkgs packages 1.0.6, which is Intel-only; 1.0.7 is a universal build
# (Apple silicon + Intel).
#
# When SensibleSideButtons releases a new version:
#   1. Find the latest version at https://github.com/archagon/sensible-side-buttons/releases
#   2. Run: nix store prefetch-file --hash-type sha256 https://github.com/archagon/sensible-side-buttons/releases/download/X.Y.Z/SensibleSideButtons-X.Y.Z.dmg
#   3. Replace `version` and the hash below with the new values.
#   4. Run `darwin-rebuild switch` to install the new version.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sensible-side-buttons";
  version = "1.0.7";

  src = fetchurl {
    url = "https://github.com/archagon/sensible-side-buttons/releases/download/${version}/SensibleSideButtons-${version}.dmg";
    hash = "sha256-+4I/F+7t82fHr1+WnZpWmm5DJEC6rNwt4j0mV3RZ4n0=";
  };

  # hdiutil needs to mount a disk image; the Nix sandbox blocks that on Darwin.
  __noChroot = true;

  # Disable fixup to prevent shebang patching from breaking the code signature.
  dontFixup = true;

  unpackPhase = ''
    mnt=$(mktemp -d)
    /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$src"
    /usr/bin/ditto "$mnt/SensibleSideButtons.app" SensibleSideButtons.app
    /usr/bin/hdiutil detach "$mnt"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    /usr/bin/ditto SensibleSideButtons.app "$out/Applications/SensibleSideButtons.app"
    runHook postInstall
  '';

  meta = {
    description = "Makes the mouse side buttons go back and forward in macOS apps";
    homepage = "https://github.com/archagon/sensible-side-buttons";
    license = lib.licenses.gpl2Only;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
