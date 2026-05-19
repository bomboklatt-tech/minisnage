{ ... }:

{
  imports = [
    ../modules/image/uefi.nix
  ];

  image.repart.name = "mininix-vm";

  # Generic VM hardware bits.
  boot.kernelParams = [ "console=ttyS0" "console=tty0" ];
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi" "virtio_gpu" "ahci"
  ];
}
