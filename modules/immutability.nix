# VM-only: when mininix.readOnlyRoot is true, mount /nix/store from
# the squashfs partition created by image.repart.
{ lib, config, ... }:

lib.mkIf config.mininix.readOnlyRoot {
  # squashfs has no filesystem-level label; use the GPT partition name
  # (PARTLABEL) instead of the typical FS label.
  fileSystems."/nix/store" = {
    device = "/dev/disk/by-partlabel/nix-store";
    fsType = "squashfs";
    neededForBoot = true;
    options = [ "loop" "ro" ];
  };
}
