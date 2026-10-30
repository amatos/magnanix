{ den, ... }: {
  den.aspects.macos.audioApps = {
    includes = [
      den.aspects.audio.airfoil
      den.aspects.audio.audioHijack
      den.aspects.audio.focusriteControl
      den.aspects.audio.farrago
      den.aspects.audio.piezo
      den.aspects.audio.fission
      den.aspects.audio.soundsource
    ];
  };
}
