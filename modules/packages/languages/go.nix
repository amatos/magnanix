# Go toolchain and development tools.
{
  den.aspects.go = {
    homeManager =
      { config, pkgs, ... }:
      {
        # Installs Go. GOPATH stays at Go's default, ~/go.
        programs.go.enable = true;

        # Binaries installed with `go install` go here.
        home.sessionPath = [ "${config.home.homeDirectory}/go/bin" ];

        home.packages = with pkgs; [
          gopls # language server (LSP)
          golangci-lint # linter runner (staticcheck, govet, errcheck, ...)
          delve # debugger (dlv)
        ];
      };
  };
}
