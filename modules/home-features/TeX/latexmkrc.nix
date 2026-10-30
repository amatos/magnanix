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
