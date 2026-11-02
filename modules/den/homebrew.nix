{ den, inputs, ... }:
{
  # nix-homebrew installs and manages Homebrew itself on macOS. Only the `darwin`
  # class is defined, so NixOS hosts are unaffected.
  den.aspects.macos.homebrew = {
    darwin.imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    includes = [
      # Needs a user, so it only applies where a host has users.
      (
        { user, ... }:
        {
          darwin = {
            homebrew = {
              enable = true;
              # Homebrew is fully declarative: on every switch, `brew bundle` uninstalls
              # any formula or cask not declared here, together with its app data
              # (`zap`), so removing a cask from the config removes it from the machine.
              onActivation.cleanup = "zap";
            };
            nix-homebrew = {
              enable = true;
              user = user.userName;
            };
          };
        }
      )
    ];
  };

  # nix-homebrew installs and manages Homebrew itself on macOS
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli/nix-homebrew";

  den.default.includes = [ den.aspects.macos.homebrew ];
}
