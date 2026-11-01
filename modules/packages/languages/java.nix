# Java runtime and development tools.
{
  den.aspects.java = {
    homeManager =
      { pkgs, ... }:
      {
        # Installs the JDK and sets JAVA_HOME.
        programs.java = {
          enable = true;
          package = pkgs.jdk;
        };

        home.packages = with pkgs; [
          maven # build tool and dependency manager
          gradle # build tool and dependency manager
          jdt-language-server # language server (LSP)
          google-java-format # code formatter
        ];
      };
  };
}
