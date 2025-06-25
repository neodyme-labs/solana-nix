{ solana, ... }:

solana.builder {
  flavour = "jito";
  version = "2.2.16";

  srcHash = "sha256-1QCeqHUSAUkuSBX0zhsa8oVU4gavFIlarfIX8Keo6Iw=";

  cargoHashes = {
    "crossbeam-epoch-0.9.5" = "sha256-Jf0RarsgJiXiZ+ddy0vp4jQ59J9m0k3sgXhWhCdhgws=";
    # "xx" = lib.fakeHash;
  };
}
