# Aspect:    den.aspects.swift
# Platforms: home-manager (installs packages on Linux only)
# Purpose:   Swift, sourcekit-lsp and swift-format on Linux.
#
# Notes:
# - On macOS nothing is installed: Swift comes from Xcode or the Command Line
#   Tools (through xcrun), matched to the SDKs.
# - swift is low priority so its bundled LLVM files (lib/libclang.so) lose to
#   clang-tools when both aspects are enabled.
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
            # Low priority: swift ships its own lib/libclang.so (and other LLVM
            # bits), which collide with clang-tools from den.aspects.c in the
            # profile. swift finds its copies through its own store path, so
            # letting clang-tools win is harmless.
            (lib.lowPrio swift) # compiler and package manager (swift build, swift test)
            sourcekit-lsp # language server (LSP)
            swift-format # formatter and linter
          ]
        );
      };
  };
}
