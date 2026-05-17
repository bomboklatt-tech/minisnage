{ inputs, pkgs, ... }:

{
  imports = [
    ../modules/image-sd.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  sdImage.populateFirmwareCommands =
    let
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
    in
    ''
      (cd ${pkgs.raspberrypifw}/share/raspberrypi/boot && \
        cp bootcode.bin fixup*.dat start*.elf $NIX_BUILD_TOP/firmware/)
      cp ${configTxt} firmware/config.txt
      cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin firmware/u-boot-rpi4.bin
      cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/armstub8-gic.bin
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-4-b.dtb firmware/
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-400.dtb firmware/
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-cm4.dtb firmware/
    '';
}
