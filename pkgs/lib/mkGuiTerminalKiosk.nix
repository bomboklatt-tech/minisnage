{ writeShellApplication, writeText, foot, cozette, lib }:

# Helper that builds a kiosk program suitable for `mininix.kiosk.package`
# in gui mode: spawns a terminal (default foot) running the supplied
# shell text. Bundles the font directly so no system-wide fontconfig is
# required.
#
# Currently foot-specific (writes a foot.ini); to support another
# terminal, copy this helper and adapt the config writer.
{
  name,
  text,
  runtimeInputs ? [ ],
  terminal ? foot,
  font ? cozette,
  fontFile ? "share/fonts/opentype/CozetteVector.otf",
  fontSize ? 13,
  extraTerminalArgs ? [ ],
}:

let
  fontPath = "${font}/${fontFile}";

  footConfig = writeText "${name}-foot.ini" ''
    [main]
    font=${fontPath}:size=${toString fontSize}
  '';

  payload = writeShellApplication {
    name = "${name}-payload";
    runtimeInputs = runtimeInputs;
    text = text;
  };

  terminalBin = "${terminal}/bin/${terminal.meta.mainProgram or "foot"}";
in
writeShellApplication {
  name = name;
  runtimeInputs = [ terminal ];
  text = ''
    exec ${terminalBin} --config=${footConfig} ${lib.escapeShellArgs extraTerminalArgs} -- ${payload}/bin/${name}-payload
  '';
}
