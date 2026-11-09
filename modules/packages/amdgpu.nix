{
  # AMD Radeon graphics (NixOS). The amdgpu kernel driver and Mesa (RADV for
  # Vulkan, radeonsi for OpenGL) are the defaults; this loads the driver early and
  # adds the 32-bit userspace that Steam and Wine/Proton need.
  den.aspects.amdgpu = {
    nixos = {
      # GPU microcode lives in linux-firmware
      hardware.enableRedistributableFirmware = true;

      hardware.amdgpu.initrd.enable = true;

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
