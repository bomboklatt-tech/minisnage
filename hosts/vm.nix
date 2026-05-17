{ ... }:

{
  imports = [
    ../modules/image-vm.nix
  ];

  # Generic x86_64 VM hardware bits.
  boot.kernelParams = [ "console=ttyS0" "console=tty0" ];
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi" "ahci"
  ];
}
