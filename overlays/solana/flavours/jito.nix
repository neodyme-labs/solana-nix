{
  # pkgs
  callPackage,
  fetchFromGitHub,
  lib,

  # build args
  agaveOverrides ? { },
  cargoHashes ? { },
  srcHash ? lib.fakeHash,
  version,

  ...
}@args:

(
  (callPackage ./agave.nix {
    inherit cargoHashes version;

    srcOverride = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${version}-jito";
      fetchSubmodules = true;

      hash = srcHash;
    };
  }).override
  agaveOverrides
).overrideAttrs
  (
    old:
    lib.attrsets.recursiveUpdate old {
      pname = "jito-cli";

      passthru.solana.jitoSupport = true;
    }
  )
