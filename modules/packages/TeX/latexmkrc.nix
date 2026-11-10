# Aspect:    den.aspects.tex.latexmk (part of den.aspects.tex)
# Platforms: home-manager
# Purpose:   Writes ~/.config/latexmk/latexmkrc (latexmk has no Home Manager
#            module).
#
# Notes:
# - $pdf_mode = 4: latexmk builds with LuaLaTeX instead of its default pdfLaTeX.
# - --shell-escape lets packages like minted run external programs;
#   --file-line-error gives file:line: error messages that editors can jump to.
{
  den.aspects.tex.latexmk = {
    homeManager = {
      # latexmk has no home-manager module; deploy ~/.config/latexmk/latexmkrc directly.
      xdg.configFile."latexmk/latexmkrc".text = ''
        # Exclude these files from the build process
        @default_excluded_files = ();

        # Set the default PDF mode to LuaLaTeX
        $pdf_mode = 4;

        # Optional: Set the specific command with desired options
        $lualatex = 'lualatex --shell-escape --file-line-error %O %S';
      '';
    };
  };
}
