# UEFI image variant: ESP with a UKI (kernel+initrd+cmdline+stub) plus
# systemd-boot as the bootloader fallback. Used by the VM target.
#
# Imports modules/image/base.nix for the cross-cutting bits (nix-store
# squashfs, tmpfs root, repart-grown var/home).
{ pkgs, config, lib, ... }:

let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
{
  imports = [
    ./base.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.enable = false;

  # Bake kernel + initrd + cmdline into a single signed EFI binary.
  boot.bootspec.enable = true;
  boot.uki.name = "mininix";

  # aarch64 EFI stub requires the kernel section to be 64K-aligned inside
  # the UKI; the ukify default (4K) trips "kernel not aligned on 64k boundary".
  # x86_64 is happy with the default.
  boot.uki.settings = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    UKI.SectionAlign = 65536;
  };

  # squashfs must be loaded in initrd before /nix/store is mounted.
  boot.initrd.kernelModules = [ "squashfs" ];

  image.repart.partitions."10-esp" = {
    contents = {
      "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
        "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
      "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
        "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
    };
    repartConfig = {
      Format = "vfat";
      Label = "boot";
      SizeMinBytes = "200M";
      Type = "esp";
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/boot";
    fsType = "vfat";
  };
}
