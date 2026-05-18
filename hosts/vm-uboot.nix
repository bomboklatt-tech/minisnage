{ lib, ... }:

# Test image mirroring the SBC boot path (u-boot -> extlinux -> kernel),
# but for qemu's `virt` machine. Reuses image-sd.nix because the boot
# flow is identical to RPi/RockPro64 (sdImage with extlinux-compatible);
# the difference is that qemu provides u-boot via -bios so we skip the
# firmware partition population step.
{
  imports = [
    ../modules/image-sd.nix
  ];

  # qemu virt doesn't need a vendor firmware blob - u-boot comes from -bios.
  sdImage.populateFirmwareCommands = "";
  # Skip zstd compression for test convenience (qemu reads .img directly).
  # image-sd.nix sets compressImage = true for the SBCs.
  sdImage.compressImage = lib.mkForce false;

  # Virtio devices exposed by qemu virt.
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi" "virtio_gpu"
  ];
  # Force-load virtio_gpu post-boot so /dev/dri/card0 is present when cage
  # starts. availableKernelModules is initrd-only; udev should auto-load
  # post-boot but doesn't always under TCG-emulated PCI enumeration.
  boot.kernelModules = [ "virtio_gpu" ];

  # Serial console on the virt machine.
  boot.kernelParams = [
    "console=ttyAMA0,115200n8"
    "console=tty0"
  ];
}
