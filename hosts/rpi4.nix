{ inputs, pkgs, ... }:

let
  # config.txt routes the RPi4 EEPROM to u-boot, which then reads the
  # extlinux.conf we drop alongside via modules/image/extlinux.nix.
  configTxt = pkgs.writeText "config.txt" ''
    [pi4]
    kernel=u-boot-rpi4.bin
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1

    [all]
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1
  '';

  # Source dirs for the RPi vendor firmware blobs. Centralising these
  # keeps the contents attrset below tidy.
  rpiFw = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
in
{
  imports = [
    ../modules/image/extlinux.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  boot.initrd.kernelModules = [
    "vc4"
    "v3d"
  ];
  image.repart.name = "mininix-rpi4";

  # /boot is the FAT partition declared by modules/image/extlinux.nix.
  # The extlinux dir + kernel + initrd are placed by that module; we
  # add the RPi4 vendor blobs and u-boot binary that the EEPROM needs.
  image.repart.partitions."10-boot".contents = {
    "/bootcode.bin".source = "${rpiFw}/bootcode.bin";
    "/start4.elf".source = "${rpiFw}/start4.elf";
    "/fixup4.dat".source = "${rpiFw}/fixup4.dat";
    "/config.txt".source = configTxt;
    "/u-boot-rpi4.bin".source = "${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin";
    "/armstub8-gic.bin".source = "${pkgs.raspberrypi-armstubs}/armstub8-gic.bin";
    "/bcm2711-rpi-4-b.dtb".source = "${rpiFw}/bcm2711-rpi-4-b.dtb";
    "/bcm2711-rpi-400.dtb".source = "${rpiFw}/bcm2711-rpi-400.dtb";
    "/bcm2711-rpi-cm4.dtb".source = "${rpiFw}/bcm2711-rpi-cm4.dtb";
  };

  # SD/eMMC media on RPi appears as /dev/mmcblk0.
  boot.initrd.systemd.repart.device = "/dev/mmcblk0";
}
