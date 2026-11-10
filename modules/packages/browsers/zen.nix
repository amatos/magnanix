# Aspect:    den.aspects.browsers.zen (part of den.aspects.browsers)
# Platforms: home-manager
# Purpose:   Zen, a Firefox-based browser, from the zen-browser-flake Home
#            Manager module, with 1Password, a Catppuccin theme and privacy
#            hardening presets.
#
# Notes:
# - darwin.packageMode = "signed": installs the app with Zen's own code
#   signature so 1Password, iCloud Passwords, Touch ID and Gatekeeper accept it.
# - Policies disable telemetry and about:config, and force-install 1Password.
# - Betterfox and arkenfox presets are applied as defaults; any entry in
#   profiles.default.settings overrides them.
# - The presets are built during evaluation (import from derivation), so a
#   darwin host that includes this can only be evaluated on a Mac.
{ inputs, ... }: {
  flake-file.inputs.zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };

  den.aspects.browsers.zen.homeManager = { pkgs, lib, ... }: {
    imports = [ inputs.zen-browser.homeModules.default ]; # or .twilight / .beta; check the flake's README
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
        ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
        };
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
