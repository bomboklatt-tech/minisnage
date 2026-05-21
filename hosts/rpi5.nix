{
  inputs,
  pkgs,
  ...
}:

let
  rpiFw = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
in
{
  imports = [
    ../modules/image/rpi-firmware.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
  ];

  image.repart.name = "mininix-rpi5";
  boot.initrd.allowMissingModules = true;
  boot.initrd.kernelModules = [
    "vc4"
    "v3d"
  ];

  # RPi5 EEPROM uses GPT and reads config.txt from the FAT partition.
  # modules/image/rpi-firmware.nix bakes Image / initramfs / cmdline.txt /
  # config.txt at the FAT root; the host's job is the matching DTB.
  image.repart.partitions."10-boot".contents = {
    "/bcm2712-rpi-5-b.dtb".source = "${rpiFw}/bcm2712-rpi-5-b.dtb";
  };

  # SD/eMMC media on RPi appears as /dev/mmcblk0.
  boot.initrd.systemd.repart.device = "/dev/mmcblk0";
}
