{ lib, ... }:

{
  options.mininix.kiosk = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = "Unprivileged user the kiosk service runs as.";
    };

    restart = lib.mkOption {
      type = lib.types.enum [ "always" "on-failure" "no" ];
      default = "always";
      description = "systemd Restart= value for the kiosk service.";
    };

    gui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        false: console kiosk that owns /dev/tty1.
        true:  Wayland kiosk via cage. Pulls wlroots, foot and font into
               the closure; gated so the console path stays small.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "pkgs.htop";
      description = ''
        Derivation whose main binary is run as the kiosk program. The
        binary is resolved via `meta.mainProgram` (with `pname` as
        fallback). In gui mode this is the program cage spawns - it must
        be a Wayland-capable application or a wrapper that produces one
        (see pkgs.mkGuiTerminalKiosk).

        Null with an empty `command` means no kiosk service runs; tty1 is
        left to getty and the user just gets an autologin shell.
      '';
    };

    command = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''[ "''${pkgs.htop}/bin/htop" "--no-color" ]'';
      description = ''
        Explicit argv-style command for the kiosk program. When non-empty
        this overrides `mininix.kiosk.package` (the binary path is
        whatever is in element 0). Use this when you need argument flags
        or when the package has no recoverable main program name.
      '';
    };

    runtimeInputs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.curl pkgs.jq ]";
      description = ''
        Extra packages prepended to PATH for the kiosk program. For
        runtime dependencies the program shells out to, without having
        to rebuild the kiosk package itself.
      '';
    };
  };
}
