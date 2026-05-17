# Shared SD-image config for aarch64 SBCs.
# Per-board firmware bits (populateFirmwareCommands) live in the host
# files because they vary heavily by SoC.
{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=ttyAMA0,115200n8"
    "console=tty0"
  ];

  sdImage = {
    compressImage = true;
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
}
