{ inputs, ... }: {
  flake-file.inputs.zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };

  den.aspects.browsers.zen.homeManager = { pkgs, lib, ... }: {
    imports = [ inputs.zen-browser.homeModules.beta ]; # or .twilight / .default; check the flake's README
    programs.zen-browser = {
      enable = true;

      # Basic setup on macOS: the upstream Zen code signature is kept (default).
      # The .app is installed untouched, so Team ID based integrations keep working:
      # 1Password, iCloud Passwords, Touch ID, Gatekeeper.
      # See https://github.com/0xc000022070/zen-browser-flake/issues/82

      darwin.packageMode = "signed";

      # Written to the `app.zen-browser.zen` defaults domain, not into the bundle.
      policies = {
        DisableTelemetry = true;
        BlockAboutConfig = true;
      };

      # firefoxpwa is Linux-only in nixpkgs, so it is skipped on macOS (evaluating
      # it there fails). Hosts are linked into the profile's NativeMessagingHosts dir.
      nativeMessagingHosts = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.firefoxpwa ];

      profiles.default = {
        id = 0;
        settings."browser.startup.homepage" = "https://example.com";
      };

      # Catppuccin theme (catppuccin/zen-browser), symlinked into the profile's
      # chrome/catppuccin and loaded via userChrome/userContent imports.
      profiles.default.presets.catppuccin = {
        enable = true;
        flavor = "Macchiato"; # Frappe | Latte | Macchiato | Mocha
        accent = "Mauve"; # Blue, Flamingo, Green, Lavender, Maroon, Mauve, ...
      };

      # Betterfox for Zen (yokoffing/Betterfox zen/user.js, aka BetterZen):
      # privacy/telemetry/performance prefs applied as mkDefault settings —
      # any profile `settings` entry wins.
      profiles.default.presets.betterfox.enable = true;

      # arkenfox for Zen (arkenfox/user.js)
      profiles.default.presets.arkenfox.enable = true;
    };
  };
}
