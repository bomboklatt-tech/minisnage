{ inputs, lib, pkgs, ... }:

{
  imports = [
    ../modules/image/extlinux.nix
    inputs.nixos-hardware.nixosModules.pine64-rockpro64
  ];

  image.repart.name = "mininix-rockpro64";

  # Required for ARM trusted firmware blob (rk3399 secure boot stub).
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3399" ];

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

  # u-boot for the RK3399 boots from two raw byte ranges before the GPT
  # proper: idbloader at sector 64 and u-boot.itb at sector 16384. We dd
  # them in after image.repart finishes via the postProcess hook.
  mininix.image.postProcess = ''
    dd if=${pkgs.ubootRockPro64}/idbloader.img of="$raw" seek=64 conv=notrunc
    dd if=${pkgs.ubootRockPro64}/u-boot.itb of="$raw" seek=16384 conv=notrunc
  '';

  # eMMC on RockPro64 typically presents as /dev/mmcblk1, microSD as
  # /dev/mmcblk0. Default to microSD.
  boot.initrd.systemd.repart.device = "/dev/mmcblk0";
}
