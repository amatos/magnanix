# Aspect:    den.aspects.c
# Platforms: home-manager
# Purpose:   C and C++ tools: clangd/clang-format/clang-tidy, CMake and Ninja;
#            on Linux also GCC and gdb.
#
# Notes:
# - On macOS the compiler and lldb come from the Xcode Command Line Tools
#   (`xcode-select --install`), which match the SDK headers, so none is
#   installed from Nix there.
{
  den.aspects.c = {
    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages =
          with pkgs;
          [
            clang-tools # clangd (LSP), clang-format, clang-tidy
            cmake # build system generator
            ninja # build system (cmake -G Ninja)
          ]
          # On macOS the compiler (clang) and debugger (lldb) come from the Xcode
          # Command Line Tools, which also provide the SDK headers.
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            gcc # compiler (cc, gcc, g++)
            gdb # debugger
          ];
      };
  };
}
