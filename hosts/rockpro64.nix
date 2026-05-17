{ inputs, lib, pkgs, ... }:

{
  imports = [
    ../modules/image-sd.nix
    inputs.nixos-hardware.nixosModules.pine64-rockpro64
  ];

  # Required for ARM trusted firmware blob (rk3399 secure boot stub).
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "arm-trusted-firmware-rk3399" ];

  # nixos-hardware enables fancontrol by default; the lm-sensors fancontrol
  # binary is a perl script, which the perlless profile bans. We replace it
  # with a direct sysfs write that pins the PWM fan to 100%.
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

  # RockPro64 needs u-boot dd'd to specific sector offsets after image
  # build. sdImage doesn't natively support this so we use postBuildCommands.
  sdImage.populateFirmwareCommands = "";

  sdImage.postBuildCommands = ''
    dd if=${pkgs.ubootRockPro64}/idbloader.img of=$img seek=64 conv=notrunc
    dd if=${pkgs.ubootRockPro64}/u-boot.itb of=$img seek=16384 conv=notrunc
  '';
}
