{
  # pkgs
  fetchFromGitHub,
  lib,
  makeRustPlatform,
  rust-bin,
  stdenv,

  # dependencies
  installShellFiles,
  openssl,
  pkg-config,
  protobuf,
  udev,

  # build args
  cargoHashes ? { },
  srcHash ? lib.fakeHash,
  srcOverride ? null,
  version,

  ...
}:

let
  src =
    if srcOverride != null then
      srcOverride
    else
      fetchFromGitHub {
        owner = "anza-xyz";
        repo = "agave";
        rev = "v${version}";

        hash = srcHash;
      };

  rustPlatform = makeRustPlatform {
    cargo = rust-bin.fromRustupToolchainFile "${src}/rust-toolchain.toml";
    rustc = rust-bin.fromRustupToolchainFile "${src}/rust-toolchain.toml";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agave-cli";
  inherit src version;

  cargoLock = {
    lockFile = "${finalAttrs.src}/Cargo.lock";
    outputHashes = cargoHashes;
  };

  strictDeps = true;

  nativeBuildInputs = [
    installShellFiles
    pkg-config
    protobuf
  ];

  buildInputs = [
    openssl
    rustPlatform.bindgenHook
    udev
  ];

  OPENSSL_NO_VENDOR = 1;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd solana \
      --bash <($out/bin/solana completion --shell bash) \
      --fish <($out/bin/solana completion --shell fish) \
      --zsh <($out/bin/solana completion --shell zsh)
  '';

  doCheck = false;

  passthru = {
    solana = {
      deploymentFlavour = "agave";
      jitoSupport = false;
    };
  };
})
