{ lib, ... }:

{
  options.mininix.debug = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Debug overlay: sets root password to "root", forces PermitRootLogin
      and PasswordAuthentication on for ssh, and adds the SULOGIN_FORCE
      kernel param so boot failures drop into a shell with no prompt.
      Intended for VM iteration; should not be active in production images.
    '';
  };
}
