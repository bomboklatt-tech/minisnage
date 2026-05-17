{ inputs, pkgs, ... }:

{
  imports = [
    ../modules/image-sd.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
  ];

  # RPi 5 boots via the EEPROM-based firmware loader (no u-boot needed).
  # The firmware partition needs RPi vendor blobs and bcm2712 DTBs.
  sdImage.populateFirmwareCommands =
    let
      configTxt = pkgs.writeText "config.txt" ''
        [all]
        arm_64bit=1
        enable_uart=1
        kernel=Image
      '';
    in
    ''
      (cd ${pkgs.raspberrypifw}/share/raspberrypi/boot && \
        cp bootcode.bin fixup*.dat start*.elf $NIX_BUILD_TOP/firmware/ 2>/dev/null || true)
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2712-rpi-5-b.dtb firmware/ || true
      cp ${configTxt} firmware/config.txt
    '';
}
