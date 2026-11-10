# Aspect:    den.aspects.elixir
# Platforms: home-manager
# Purpose:   Erlang/OTP, Elixir (mix, iex, mix format) and ElixirLS, all from
#            one beamPackages set so they share an OTP release.
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
