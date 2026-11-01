# Python runtime and development tools.
{
  den.aspects.python = {
    homeManager =
      { lib, pkgs, ... }:
      {
        # Hatch has no global installer setting (`installer = "uv"` is per project),
        # but it uses uv for every virtual environment when this path is set.
        home.sessionVariables.HATCH_ENV_TYPE_VIRTUAL_UV_PATH = lib.getExe pkgs.uv;

        home.packages = with pkgs; [
          python3 # runtime
          uv # project, dependency, virtualenv and Python version manager
          hatch # project manager, environments, builds and publishing
          ruff # linter and formatter
          black # code formatter
          basedpyright # language server (LSP) and type checker
          mypy # static type checker
        ];
      };
  };
}
