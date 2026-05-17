# VM-only: when userConfig.readOnlyRoot is true, mount /nix/store from
# the squashfs partition created by image.repart.
{ lib, userConfig, ... }:

lib.mkIf userConfig.readOnlyRoot {
  fileSystems."/nix/store" = {
    device = "/dev/disk/by-label/nix-store";
    fsType = "squashfs";
    neededForBoot = true;
    options = [ "ro" ];
  };
}
