{ writeShellApplication, neo-cowsay, coreutils }:

# neo-cowsay (Go) instead of upstream cowsay (Perl) - perl-free closure.
writeShellApplication {
  name = "hello-kiosk";
  runtimeInputs = [ neo-cowsay coreutils ];
  text = ''
    cowsay "hello from mininix"
    exec sleep infinity
  '';
}
