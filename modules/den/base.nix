{ den, ... }:
{
  # Baseline configuration for every host.
  den.aspects.base = {
    # Sets the OS hostname from the Den host name, which must match
    # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS).
    includes = [ den.batteries.hostname ];

    # Shared by all hosts (`os` lands in `darwin` on macOS and `nixos` on NixOS)
    os = { };

    # macOS-only baseline
    darwin = { };

    # NixOS-only baseline
    nixos = { };
  };

  den.default.includes = [ den.aspects.base ];
}
