# Aspect:    den.aspects.audio
# Platforms: nixos, darwin
# Purpose:   The audio bundle. On macOS, the Rogue Amoeba apps and Focusrite
#            Control as casks; on NixOS, PipeWire as the sound server.
#
# Notes:
# - NixOS: PipeWire replaces PulseAudio. pulse.enable keeps PulseAudio apps
#   working, alsa.support32Bit is for 32-bit apps such as Steam games.
# - Every user on the host is added to the `audio` group, for direct access to
#   sound devices.
{ den, lib, ... }: {
  den.aspects.audio = {
    includes = [
      den.aspects.audio.macos.airfoil
      den.aspects.audio.macos.audioHijack
      den.aspects.audio.macos.farrago
      den.aspects.audio.macos.fission
      den.aspects.audio.macos.focusriteControl
      den.aspects.audio.macos.piezo
      den.aspects.audio.macos.soundsource

      ({ host, ... }: {
        nixos.users.users = lib.genAttrs (lib.attrNames host.users) (_: {
          extraGroups = [ "audio" ];
        });
      })
    ];

    nixos = {
      services = {
        pipewire = {
          alsa = {
            enable = true;
            support32Bit = true;
          };

          enable = true;
          pulse.enable = true;
        };
      };
    };
  };
}
