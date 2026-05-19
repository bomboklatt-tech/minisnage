{
  pkgs,
  ...
}:

{
  imports = [
    ../modules/image/extlinux.nix
  ];

  image.repart.name = "mininix-orangepi-pc";

  # Pin the H3 DTB. With a single DTB on disk u-boot's distro_bootcmd
  # gets an explicit FDT line in extlinux.conf instead of having to
  # guess from FDTDIR + board model - more reliable on older sunxi
  # u-boot builds and keeps the image board-locked, which matches
  # mininix's "one image per board" appliance model.
  hardware.deviceTree.name = "allwinner/sun8i-h3-orangepi-pc.dtb";

  # UART0 on the 3-pin debug header is the serial console on the OPi PC.
  # tty0 keeps HDMI usable so the kiosk can show up on an attached display.
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  # SD card on Allwinner SoCs enumerates as /dev/mmcblk0.
  boot.initrd.systemd.repart.device = "/dev/mmcblk0";

  # H3 BootROM probes sector 16 (8 KiB) and sector 256 (128 KiB) for an
  # SPL signature. We use the 128 KiB slot: it sits above the GPT primary
  # header (sectors 1-33) and below the 1 MiB first-partition boundary
  # that image.repart leaves clear at the head of the disk, so the GPT
  # stays valid and no special partition offsets are needed.
  mininix.image.postProcess = ''
    dd if=${pkgs.ubootOrangePiPc}/u-boot-sunxi-with-spl.bin \
       of="$raw" bs=1024 seek=128 conv=notrunc
  '';
}
