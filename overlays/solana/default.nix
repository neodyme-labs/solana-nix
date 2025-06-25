final: prev:

let
  flavours = {
    agave = ./flavours/agave.nix;
    jito = ./flavours/jito.nix;
  };
in
{
  solana.builder =
    { flavour, ... }@args:
    final.callPackage flavours.${flavour} (final.lib.removeAttrs args [ "flavour" ]);
}
