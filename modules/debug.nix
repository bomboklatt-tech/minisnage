# Debug overlay - applies when config.nix sets `debug = true`.
# Intended for VM iteration; should not be active in production images.
{ lib, userConfig, ... }:

lib.mkIf userConfig.debug {
  # Drop straight into a root shell when boot fails (no password prompt
  # from sulogin). This is what was previously hand-edited into image-vm.
  boot.kernelParams = [ "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];

  # Plaintext root password "root" plus SSH password auth, so the user can
  # log in without an ssh key being configured.
  users.users.root.password = "root";
  users.mutableUsers = false;

  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
  };
}
