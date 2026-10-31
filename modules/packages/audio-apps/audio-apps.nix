{ den, ... }: {
  den.aspects.macos.audioApps = {
    includes = [
      den.aspects.audio.macos.airfoil
      den.aspects.audio.macos.audioHijack
      den.aspects.audio.macos.focusriteControl
      den.aspects.audio.macos.farrago
      den.aspects.audio.macos.piezo
      den.aspects.audio.macos.fission
      den.aspects.audio.macos.soundsource
    ];
  };
}
