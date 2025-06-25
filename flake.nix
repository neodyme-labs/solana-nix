{
  description = "Various solana clients packaged for nix";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Include required systems
      systems = [ "x86_64-linux" ];

      flake = {
        nixosModules = {
          solana = import ./modules/solana;
        };

        overlays = rec {
          default = solana;
          solana = import ./overlays/solana;
        };
      };

      perSystem = { pkgs, system, ... }:
      {
        # Include required overlays
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;

          overlays = [
            inputs.rust-overlay.overlays.default
            self.overlays.solana
          ];
        };

        packages = {
          agave = pkgs.callPackage ./packages/agave.nix { };
          jito = pkgs.callPackage ./packages/jito.nix { };
        };
      };
    };
}
