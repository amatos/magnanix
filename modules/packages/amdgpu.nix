# Aspect:    den.aspects.amdgpu
# Platforms: nixos
# Purpose:   AMD Radeon graphics: loads amdgpu early (in the initrd) and adds the
#            firmware and 32-bit Mesa that Steam and Wine/Proton need.
{
  # The amdgpu kernel driver and Mesa (RADV for Vulkan, radeonsi for OpenGL)
  # are NixOS's defaults already; this only adds what they lack.
  den.aspects.amdgpu = {
    nixos = {
      # GPU microcode lives in linux-firmware
      hardware.enableRedistributableFirmware = true;

      # Load amdgpu in the initrd rather than after switching to the real root,
      # so the display is driven natively from early boot (e.g. the LUKS prompt).
      hardware.amdgpu.initrd.enable = true;

      # 32-bit Mesa alongside the 64-bit one, for 32-bit games (Steam, Wine/Proton).
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
