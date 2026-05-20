{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../modules/image/extlinux.nix
    inputs.nixos-hardware.nixosModules.pine64-rockpro64
  ];

  image.repart.name = "mininix-rockpro64";

  # Required for ARM trusted firmware blob (rk3399 secure boot stub).
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3399" ];

  # nixos-hardware enables fancontrol by default; the lm-sensors
  # fancontrol binary is a perl script, which the perlless profile bans.
  # We replace it with a direct sysfs write pinning the PWM fan to 100%.
  hardware.fancontrol.enable = false;

  systemd.services.rockpro64-fan-max = {
    description = "Pin RockPro64 PWM fan to 100%";
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for hwmon in /sys/class/hwmon/hwmon*; do
        if [ -f "$hwmon/name" ]; then
          name=$(cat "$hwmon/name")
          case "$name" in
            pwm-fan|pwmfan)
              [ -f "$hwmon/pwm1_enable" ] && echo 1 > "$hwmon/pwm1_enable" || true
              echo 255 > "$hwmon/pwm1"
              exit 0
              ;;
          esac
        fi
      done
      echo "pwm-fan hwmon device not found" >&2
      exit 1
    '';
  };

  # rk3399 BootROM loads u-boot from two fixed raw-byte offsets:
  # idbloader at LBA 64 (32 KiB) and u-boot.itb at LBA 16384 (8 MiB).
  # idbloader lands in the gap before LBA 2048 and never collides with
  # anything. u-boot.itb at LBA 16384 lands deep inside the GPT-managed
  # area, so the partition that owns those sectors must not have a
  # filesystem allocating data there. If the FAT in /boot extends across
  # LBA 16384 (kernel + initrd > ~7 MiB, easily triggered by larger
  # closures pulling more modules into initrd), the postProcess dd
  # silently corrupts initrd and the kernel reports
  # "initramfs unpacking failed: ZSTD-compressed data is corrupt".
  #
  # `00-uboot` reserves LBAs 2048..32767 (15 MiB) with the GPT BIOS-boot
  # type UUID so nothing auto-mounts it, pushing the boot partition to
  # start at LBA 32768 (16 MiB). u-boot.itb at LBA 16384 then lands
  # entirely inside the reserved partition's range and the FAT in /boot
  # is undisturbed.
  image.repart.partitions."00-uboot" = {
    repartConfig = {
      Type = "21686148-6449-6e6f-744e-656564454649";
      Label = "uboot";
      SizeMinBytes = "15M";
      SizeMaxBytes = "15M";
    };
  };

  mininix.image.postProcess = ''
    dd if=${pkgs.ubootRockPro64}/idbloader.img of="$raw" seek=64 conv=notrunc
    dd if=${pkgs.ubootRockPro64}/u-boot.itb of="$raw" seek=16384 conv=notrunc
  '';

  # eMMC = /dev/mmcblk0 on RockPro64
  # sd = /dev/mmcblk1
  boot.initrd.systemd.repart.device = "/dev/mmcblk1";
  boot.kernelParams = [
    "console=ttyS2,1500000n8"
    # "earlycon=uart8250,mmio32,0xff1a0000"
  ];
}
