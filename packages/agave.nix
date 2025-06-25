{ solana, ... }:

solana.builder {
  flavour = "agave";
  version = "2.2.16";

  srcHash = "sha256-ctKW5FUH8w9MhgE5WNCOt6ET0QF1HvpUW4h6yE2LH0A";

  cargoHashes = {
    "crossbeam-epoch-0.9.5" = "sha256-Jf0RarsgJiXiZ+ddy0vp4jQ59J9m0k3sgXhWhCdhgws=";
    # "xx" = lib.fakeHash;
  };
}
