{ pkgs, lib, config, ... }:

let
  cfg = config.mininix.kiosk;

  # Resolve the kiosk command from `command` (if set) or `package`.
  # null = no kiosk service runs (autologin path only).
  resolvedCommand =
    if cfg.command != [ ] then cfg.command
    else if cfg.package != null then
      let
        bin =
          cfg.package.meta.mainProgram or
          cfg.package.pname or
          (throw ''
            mininix.kiosk.package has no `meta.mainProgram` or `pname`.
            Set `mininix.kiosk.command` explicitly with the binary path
            and any arguments.
          '');
      in [ "${cfg.package}/bin/${bin}" ]
    else null;

  hasKiosk = resolvedCommand != null;

  # Single wrapper used by both the console service and cage. Carries
  # runtimeInputs on PATH so the kiosk command can shell out to extras.
  kioskProgram = pkgs.writeShellApplication {
    name = "mininix-kiosk";
    runtimeInputs = cfg.runtimeInputs;
    text = "exec ${lib.escapeShellArgs (if hasKiosk then resolvedCommand else [ "true" ])}";
  };

  kioskBin = "${kioskProgram}/bin/mininix-kiosk";
in

lib.mkMerge [
  # Shared: user + group + autologin on tty2-tty6.
  {
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      home = "/home/${cfg.user}";
      createHome = true;
      shell = pkgs.bashInteractive;
    };
    users.groups.${cfg.user} = { };

    services.getty.autologinUser = cfg.user;
  }

  # Console path: kiosk service owns tty1.
  (lib.mkIf (!cfg.gui && hasKiosk) {
    systemd.services."getty@tty1".enable = false;

    systemd.services.kiosk = {
      description = "mininix kiosk task (console)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "systemd-user-sessions.service" ];
      wants = [ "network-online.target" ];
      conflicts = [ "getty@tty1.service" ];
      serviceConfig = {
        Type = "idle";
        ExecStart = kioskBin;
        User = cfg.user;
        Restart = cfg.restart;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
      };
    };
  })

  # GUI path: cage owns tty1 and spawns the kiosk program (Wayland).
  # All wayland/wlroots/foot deps only enter the closure on this path.
  (lib.mkIf (cfg.gui && hasKiosk) {
    services.cage = {
      enable = true;
      user = cfg.user;
      program = kioskBin;
    };

    # cage opens /dev/dri/card0 (video) and uses libseat for session
    # management. Without these groups wlroots fails with "Failed to open
    # any DRM device" / libseat "No such device".
    users.users.${cfg.user}.extraGroups = [ "video" "render" "input" "seat" ];

    # services.cage sets hardware.graphics = mkDefault true, but our
    # minimization module pins it false at default priority. Force it on.
    hardware.graphics.enable = lib.mkForce true;
  })
]
