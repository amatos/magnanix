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
