{ inputs, ... }: {
  flake-file.inputs.zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };

  den.aspects.browsers.zen.homeManager = {
    imports = [ inputs.zen-browser.homeModules.beta ]; # or .twilight / .default; check the flake's README
    programs.zen-browser.enable = true;
  };
}
