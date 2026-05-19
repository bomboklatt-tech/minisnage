{ lib, ... }:

{
  options.mininix = {
    readOnlyRoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Mount /nix/store from the squashfs partition produced by
        image.repart, leaving the rest of the filesystem on a tmpfs root.
        Setting false would require additional work and is not currently
        supported - the squashfs partition is always produced.
      '';
    };

    image.postProcess = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = lib.literalExpression ''
        '''
          dd if=''${pkgs.ubootRockPro64}/idbloader.img of="$raw" seek=64 conv=notrunc
        '''
      '';
      description = ''
        Shell snippet run on the raw image file after image.repart finishes.
        Used to splice bytes the image-building pipeline can't otherwise
        place - e.g. u-boot at fixed sector offsets on the RockPro64.

        Variables in scope when the snippet runs:
          - `$raw`: absolute path to the raw image file in the output dir
                    (already chmodded writable).
          - `$out`: absolute path to the output directory.

        Default is empty; the unmodified repart output is used.
      '';
    };
  };
}
