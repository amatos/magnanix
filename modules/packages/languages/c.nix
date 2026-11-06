# C and C++ development tools.
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
