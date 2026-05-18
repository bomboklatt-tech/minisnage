{ lib, ... }:

{
  options.mininix.hostname = lib.mkOption {
    type = lib.types.str;
    default = "mininix";
    description = "System hostname; applied to every host built from this flake.";
  };
}
