# Direct-firmware image variant for Raspberry Pi.
#
# The RPi EEPROM reads `config.txt` from the first FAT partition and
# loads the kernel + initramfs straight from that partition, with no
# u-boot in between. We pre-bake everything the firmware needs (Image,
# initramfs, cmdline.txt, config.txt and optional vendor blobs) into
# the FAT root at image build time.
#
# Host-specific files (the matching `.dtb`, board-specific config.txt
# tweaks) come from the host file by extending
# `image.repart.partitions."10-boot".contents` or by setting
# `mininix.image.rpiConfigTxt`.
#
# Imports modules/image/base.nix for the cross-cutting bits.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.mininix.image;

  cmdline = lib.concatStringsSep " " (
    config.boot.kernelParams ++ [ "init=${config.system.build.toplevel}/init" ]
  );

  configTxtFile = pkgs.writeText "config.txt" cfg.rpiConfigTxt;
  cmdlineFile = pkgs.writeText "cmdline.txt" cmdline;

  # Pre-bake the FAT root: kernel + initramfs + cmdline.txt + config.txt
  # (and, optionally, the legacy RPi <=4 vendor blobs). The host adds
  # the matching DTB separately via image.repart contents.
  bootFiles = pkgs.runCommand "${config.image.repart.name}-boot" { } ''
    mkdir -p $out
    cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} $out/Image
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} $out/initramfs
    cp ${configTxtFile} $out/config.txt
    cp ${cmdlineFile} $out/cmdline.txt
    ${lib.optionalString cfg.rpiIncludeVendorBlobs ''
      # RPi <=4 early-boot stages. RPi5's EEPROM does its own early
      # boot so these are redundant there, but the firmware package
      # ships them as a common set and including them is harmless.
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bootcode.bin $out/ 2>/dev/null || true
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/start*.elf   $out/ 2>/dev/null || true
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup*.dat   $out/ 2>/dev/null || true
    ''}
  '';
in
{
  imports = [
    ./base.nix
  ];

  options.mininix.image = {
    rpiConfigTxt = lib.mkOption {
      type = lib.types.lines;
      default = ''
        [all]
        arm_64bit=1
        enable_uart=1
        kernel=Image
        initramfs initramfs followkernel
      '';
      description = ''
        Contents of /config.txt on the RPi firmware boot partition.
        Override per host to add board-specific stanzas (e.g. [pi5]).
      '';
    };

    rpiIncludeVendorBlobs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      internal = true;
      description = ''
        Copy bootcode.bin / start*.elf / fixup*.dat from raspberrypifw
        into the FAT root. Needed for RPi <=4; redundant on RPi5.
      '';
    };
  };

  config = {
    # No second-stage bootloader: the EEPROM is the loader.
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = false;

    # squashfs must load in initrd before /nix/store is mounted.
    boot.initrd.kernelModules = [ "squashfs" ];

    image.repart.partitions."10-boot" = {
      contents."/".source = bootFiles;
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
  };
}
