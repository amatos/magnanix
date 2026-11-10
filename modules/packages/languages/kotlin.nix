# Aspect:    den.aspects.kotlin (includes den.aspects.java)
# Platforms: home-manager
# Purpose:   kotlinc, kotlin-language-server and ktlint, all rebuilt on JDK 25;
#            JAVA_HOME, Gradle and Maven come from the java aspect.
{ den, ... }:
{
  den.aspects.kotlin = {
    # The JDK (JAVA_HOME), Gradle and Maven come from the java aspect.
    includes = [ den.aspects.java ];

    homeManager =
      { pkgs, ... }:
      let
        # The java aspect's JDK, so every tool runs on the same JDK as JAVA_HOME.
        jdk = pkgs.jdk25;
      in
      {
        home.packages = with pkgs; [
          (kotlin.override { jre = jdk; }) # compiler (kotlinc) and REPL
          (kotlin-language-server.override { openjdk = jdk; }) # language server (LSP)
          (ktlint.override { jre_headless = jdk; }) # linter and formatter
        ];
      };
  };
}
