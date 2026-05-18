{ writeShellApplication, foot, neo-cowsay, coreutils }:

# Wayland variant of hello-kiosk: spawns a foot terminal (run under cage by
# services.cage) and runs the cowsay loop inside it.
writeShellApplication {
  name = "hello-kiosk-gui";
  runtimeInputs = [ foot neo-cowsay coreutils ];
  text = ''
    exec foot -- sh -c 'cowsay "hello from mininix (wayland)"; exec sleep infinity'
  '';
}
