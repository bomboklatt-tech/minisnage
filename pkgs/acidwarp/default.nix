{
  mkGuiTerminalKiosk,
  writeText,
  dosbox-staging,
}:

let
  conf = writeText "dosbox.conf" ''
    [sdl]
    fullscreen = on
    output = opengl

    [render]
    aspect = on

    [cpu]
    cycles = max

    [dosbox]
    machine = vgaonly

    [autoexec]
    @echo off
    mount d ${./.}
    d:
    ACIDWARP.EXE
    exit
  '';
in
mkGuiTerminalKiosk {
  name = "acidwarp";
  runtimeInputs = [ dosbox-staging ];
  text = ''
  export SDL_VIDEODRIVER=wayland
  dosbox-staging -conf ${conf}
  '';
}
