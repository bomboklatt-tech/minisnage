{ pkgs, config, lib, modulesPath, ... }:

let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
{
  imports = [
    (modulesPath + "/image/repart.nix")
    ./immutability.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.enable = false;

  # Bake kernel + initrd + cmdline into a single signed EFI binary.
  boot.bootspec.enable = true;
  boot.uki.name = "mininix";

  image.repart = {
    name = "mininix-vm";
    partitions = {
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = {
          Format = "vfat";
          Label = "boot";
          SizeMinBytes = "200M";
          Type = "esp";
        };
      };
      "20-store" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Format = "squashfs";
          Label = "nix-store";
          Minimize = "guess";
          ReadOnly = "yes";
          Type = "linux-generic";
        };
      };
    };
  };

  # First-boot inflation.
  boot.initrd.systemd.repart.enable = true;
  boot.initrd.systemd.repart.device = "/dev/vda";

  systemd.repart.partitions = {
    "30-var" = {
      Format = "ext4";
      Label = "var";
      Type = "var";
      Weight = 1000;
    };
    "40-home" = {
      Format = "ext4";
      Label = "home";
      Type = "home";
      Weight = 2000;
    };
  };

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-label/var";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/home";
    fsType = "ext4";
  };
}
