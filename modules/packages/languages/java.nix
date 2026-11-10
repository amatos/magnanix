# Aspect:    den.aspects.java
# Platforms: home-manager
# Purpose:   JDK 25 (current LTS) as JAVA_HOME, with Maven, Gradle 9, jdtls,
#            google-java-format and JBang.
#
# Notes:
# - Tools that would default to an older JDK are rebuilt against JDK 25, so
#   there's exactly one JDK and every tool runs on the same one as JAVA_HOME.
{
  den.aspects.java = {
    homeManager =
      { pkgs, ... }:
      let
        # Current LTS. The tools that default to an older JDK are built against it too,
        # so there is one JDK and every tool runs on the same JDK as JAVA_HOME.
        jdk = pkgs.jdk25;
      in
      {
        # Installs the JDK and sets JAVA_HOME.
        programs.java = {
          enable = true;
          package = jdk;
        };

        home.packages = with pkgs; [
          (maven.override { jdk_headless = jdk; }) # build tool and dependency manager
          (gradle_9.override { java = jdk; }) # build tool and dependency manager
          jdt-language-server # language server (LSP), already built on JDK 25
          (google-java-format.override { jre = jdk; }) # code formatter
          (jbang.override { inherit jdk; }) # run Java scripts with dependencies
        ];
      };
  };
}
