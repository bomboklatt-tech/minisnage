{ mkGuiTerminalKiosk, neo-cowsay }:

# Default Wayland kiosk: cowsay in a foot terminal, font from cozette.
# Demonstrates the typical use of pkgs.mkGuiTerminalKiosk.
mkGuiTerminalKiosk {
  name = "hello-kiosk-gui";
  runtimeInputs = [ neo-cowsay ];
  text = ''
    cowsay "hello from mininix (wayland)"
    exec sleep infinity
  '';
}
