{ den, inputs, ... }:
{
  # nix-homebrew installs and manages Homebrew itself on macOS. Only the `darwin`
  # class is defined, so NixOS hosts are unaffected.
  den.aspects.homebrew = {
    darwin.imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    includes = [
      # Needs a user, so it only applies where a host has users.
      (
        { user, ... }:
        {
          darwin = {
            homebrew.enable = true;
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

  den.default.includes = [ den.aspects.homebrew ];
}
