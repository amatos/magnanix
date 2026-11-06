# Swift toolchain and development tools.
{
  den.aspects.swift = {
    # On macOS Swift comes from Xcode or the Command Line Tools (swift, swiftc,
    # sourcekit-lsp and swift-format, through xcrun), matched to the SDKs, so
    # nothing is installed there.
    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux (
          with pkgs;
          [
            swift # compiler and package manager (swift build, swift test)
            sourcekit-lsp # language server (LSP)
            swift-format # formatter and linter
          ]
        );
      };
  };
}
