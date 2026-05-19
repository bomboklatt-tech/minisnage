# extlinux/u-boot image variant: a FAT /boot partition with the kernel,
# initrd, DTBs and extlinux config, loaded by u-boot via its generic
# distro boot scanning. Used by vm-uboot and every SBC host.
#
# Per-host firmware (RPi vendor blobs, etc.) goes into the same /boot
# partition by extending `image.repart.partitions."10-boot".contents`
# in the host file. NixOS module merge composes them.
#
# Imports modules/image/base.nix for the cross-cutting bits.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  # Pre-bake the extlinux directory tree that
  # boot.loader.generic-extlinux-compatible.populateCmd writes at
  # activation time. By generating it here we can drop it into the FAT
  # at image build time, which is what u-boot's generic distro mode
  # expects to find on boot.
  extlinuxBoot = pkgs.runCommand "${config.image.repart.name}-extlinux" { } ''
    mkdir -p $out
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
      -c ${config.system.build.toplevel} -d $out
  '';
in
{
  imports = [
    ./base.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # squashfs must be loaded in initrd before /nix/store is mounted.
  boot.initrd.kernelModules = [ "squashfs" ];

  image.repart.partitions."10-boot" = {
    contents = {
      "/".source = extlinuxBoot;
    };
    repartConfig = {
      Format = "vfat";
      Label = "boot";
      SizeMinBytes = "200M";
      # ESP type so u-boot's distro_bootcmd picks the partition up first.
      Type = "esp";
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/boot";
    fsType = "vfat";
  };
}
