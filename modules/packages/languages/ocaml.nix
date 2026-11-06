# OCaml compiler and development tools.
{
  den.aspects.ocaml = {
    homeManager =
      { pkgs, ... }:
      let
        # Packages built against the same compiler as `ocaml`.
        ocamlPackages = pkgs.ocamlPackages;
      in
      {
        home.packages = [
          ocamlPackages.ocaml # compiler and toplevel
          ocamlPackages.dune_3 # build system
          ocamlPackages.ocaml-lsp # language server (LSP)
          pkgs.ocamlformat # formatter

          # Package and compiler-switch manager, only needed for opam-based projects,
          # libraries missing from ocamlPackages or other compilers (see the README).
          # Installed without shell integration: `opam env` fails until `opam init`
          # has been run. After that, activate a switch with `eval $(opam env)`.
          pkgs.opam
        ];
      };
  };
}
