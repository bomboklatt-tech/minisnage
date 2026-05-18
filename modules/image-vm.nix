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

  # aarch64 EFI stub requires the kernel section to be 64K-aligned within
  # the UKI; the ukify default (4K) trips "kernel not aligned on 64k boundary".
  # x86_64 is happy with the default.
  boot.uki.settings = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    UKI.SectionAlign = 65536;
  };

  # squashfs must be loaded in initrd before /nix/store is mounted.
  boot.initrd.kernelModules = [ "squashfs" ];

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
        # Mounted at /nix/store; store paths sit at "/" inside the squashfs
        # so the in-store layout matches /nix/store/<hash> post-mount.
        # Without this, default "/nix/store" produces /nix/store/nix/store/<hash>
        # and the cmdline init= path fails to canonicalize after switch_root.
        nixStorePrefix = "/";
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

  # by-partlabel (GPT partition name) instead of by-label (FS label):
  # FAT uppercases its FS label, squashfs has none, and the per-partition
  # GPT name is set deterministically by systemd-repart.
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/boot";
    fsType = "vfat";
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-partlabel/var";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-partlabel/home";
    fsType = "ext4";
  };
}
