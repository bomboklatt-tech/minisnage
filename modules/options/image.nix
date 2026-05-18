{ lib, ... }:

{
  options.mininix.readOnlyRoot = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      VM image only: mount /nix/store from the squashfs partition produced
      by image.repart, leaving the rest of the filesystem on a tmpfs root.
      Ignored on SBC images (sdImage is mutable ext4 by design).
    '';
  };
}
