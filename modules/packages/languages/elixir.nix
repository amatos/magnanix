# Elixir runtime and development tools.
{
  den.aspects.elixir = {
    homeManager =
      { pkgs, ... }:
      let
        # One BEAM package set, so Elixir, Erlang and the language server share
        # an Erlang/OTP release.
        beam = pkgs.beamPackages;
      in
      {
        home.packages = [
          beam.erlang # Erlang/OTP runtime (erl, escript)
          beam.elixir # compiler, mix, iex and formatter (mix format)
          beam.elixir-ls # language server (LSP) and debugger
        ];
      };
  };
}
