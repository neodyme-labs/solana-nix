{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optionals
    types
    ;

  cfg = config.services.solana-validator;

  clusterDefaults = {
    mainnet = {
      genesisHash = "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d";

      entrypoints = [
        "entrypoint.mainnet-beta.solana.com:8001"
        "entrypoint2.mainnet-beta.solana.com:8001"
        "entrypoint3.mainnet-beta.solana.com:8001"
        "entrypoint4.mainnet-beta.solana.com:8001"
        "entrypoint5.mainnet-beta.solana.com:8001"
      ];

      trustedValidators = [
        "7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2"
        "GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ"
        "DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ"
        "CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S"
      ];

      metricsConfig = {
        host = "https://metrics.solana.com:8086";
        db = "mainnet-beta";
        user = "mainnet-beta_write";
        password = "password";
      };

      jito = {
        tipPaymentProgram = "T1pyyaTNZsKv2WcRAB8oVnk93mLJw2XzjtVYqCsaHqt";
        tipDistributionProgram = "4R3gSG8BpU4t19KYj8CfnbtRpnT8gtk4dvTHxVRwc2r7";
        merkleRootUploadAuthority = "GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib";
      };
    };

    testnet = {
      genesisHash = "4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY";

      entrypoints = [
        "entrypoint.testnet.solana.com:8001"
        "entrypoint2.testnet.solana.com:8001"
        "entrypoint3.testnet.solana.com:8001"
      ];

      trustedValidators = [
        "5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on"
        "dDzy5SR3AXdYWVqbDEkVFdvSPCtS9ihF5kJkHCtXoFs"
        "Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN"
        "eoKpUABi59aT4rR9HGS3LcMecfut9x7zJyodWWP43YQ"
        "9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv"
      ];

      metricsConfig = {
        host = "https://metrics.solana.com:8086";
        db = "tds";
        user = "testnet_write";
        password = "c4fa841aa918bf8274e3e2a44d77568d9861b3ea";
      };

      jito = {
        tipPaymentProgram = "DCN82qDxJAQuSqHhv2BJuAgi41SPeKZB5ioBCTMNDrCC";
        tipDistributionProgram = "F2Zu7QZiTYUhPd7u9ukRVwxh7B71oA3NMJcHuCHc29P2";
        merkleRootUploadAuthority = "GZctHpWXmsZC1YHACTGGcHhYxjdRqQvTpYkb9LMvxDib";
      };
    };
  };

  defaultValue = name: {
    default = clusterDefaults.${cfg.cluster or (throw "a")}.${name};
    defaultText = "Default value selected according to cluster chosen in `cluster`.";
  };

  defaultValue2 = top: name: {
    default = clusterDefaults.${cfg.cluster or (throw "a")}.${top}.${name};
    defaultText = "Default value selected according to cluster chosen in `cluster`.";
  };
in
{
  imports = [
    ./flavours/agave
  ];

  options.services.solana-validator = {
    enable = mkEnableOption "solana validator";
    enableUpstreamMetrics = mkEnableOption "metrics upstreaming";
    enableVoting = mkEnableOption "voting";

    user = mkOption {
      type = types.str;
      default = "solana";
      description = "User the validator should run as.";
    };

    group = mkOption {
      type = types.str;
      default = "solana";
      description = "Group the validator should run as.";
    };

    dataDir = mkOption rec {
      type = types.str;
      default = "/var/lib/solana";
      description = "Directory to store all data.";
    };

    logDir = mkOption rec {
      type = types.str;
      default = "/var/log/solana";
      description = "Directory to store logs.";
    };

    package = mkOption {
      type = types.package;
      default = config.programs.solana.package;
      defaultText = literalExpression "programs.solana.package";
      description = "Solana package to use for the validator.";
    };

    flavour = mkOption {
      type = types.enum [ ];
      default =
        cfg.package.solana.deploymentFlavour or (throw ''
          The package provided to ´services.solana-validator.package` does not specify a `solana.deploymentFlavour`
          passthru value. You will need to specify the flavour of the validator to run manually to
          `services.solana-validator.flavour`.

          Provided package: ${builtins.toString cfg.package}
        '');
      defaultText = "`solana.deploymentFlavour` passthru of the `package`.";
      description = "Flavour of the validator to run.";
    };

    cluster = mkOption {
      type = types.enum (builtins.attrNames clusterDefaults);
      description = "Well-Known clusters to apply the default values from.";
    };

    entrypoints =
      mkOption {
        type = with types; listOf str;
        description = "Entrypoints.";
      }
      // defaultValue "entrypoints";

    genesisHash =
      mkOption {
        type = types.str;
        description = "The genesis hash of the cluster.";
      }
      // defaultValue "genesisHash";

    identityPath = mkOption {
      type = types.str;
      description = "Path to the identity keypair of the validator.";
    };

    jito = {
      enable = mkEnableOption "jito";

      blockEngineURL = mkOption {
        type = types.str;
        description = "URL of the jito block engine.";
      };

      commissionBps = mkOption {
        type = types.int;
        description = "Jito commission to configure (in basis points (0.01%)).";
      };

      merkleRootUploadAuthority =
        mkOption {
          type = types.str;
          description = "Address of the jito merkle root upload authority.";
        }
        // defaultValue2 "jito" "merkleRootUploadAuthority";

      relayerURL = mkOption {
        type = types.str;
        description = "URL of the jito relayer.";
      };

      shredReceiverAddress = mkOption {
        type = types.str;
        description = "Address of the jito shred receiver.";
      };

      tipDistributionProgram =
        mkOption {
          type = types.str;
          description = "Address of the jito tip distribution program.";
        }
        // defaultValue2 "jito" "tipDistributionProgram";

      tipPaymentProgram =
        mkOption {
          type = types.str;
          description = "Address of the jito tip payment program.";
        }
        // defaultValue2 "jito" "tipPaymentProgram";
    };

    logCleanup = {
      enable = mkEnableOption "automatic log directory cleanup" // {
        default = cfg.logDir == "/var/log/solana";
        defaultText = "True if using default log directory.";
      };

      reloadCalendar = mkOption {
        type = types.str;
        default = "daily";
        description = "Calendar config used for the rotation of log-files.";
      };

      retention = mkOption {
        type = types.str;
        default = "5d";
        description = "The maximum age of log files in the `logDir` directory.";
      };
    };

    openFirewall = mkEnableOption "opening of the firewall." // {
      default = true;
    };

    restartIfChanged = mkOption {
      type = types.bool;
      default = !cfg.enableVoting;
      defaultText = literalExpression "!cfg.enableVoting";
      description = "Whether to restart the validator automatically upon changes.";
    };

    rpc = {
      listenAddress = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Address RPC will bind to.";
      };

      port = mkOption {
        type = types.port;
        default = 8899;
        description = "RPC port.";
      };

      publish = mkEnableOption "publishing of the RPC port in gossip and opening of the firewall if configured to do so.";
    };

    trustedValidators =
      mkOption {
        type = with types; listOf str;
        description = "Known validators, trusted by this validator.";
      }
      // defaultValue "trustedValidators";

    upstreamMetricsConfig =
      mkOption {
        type =
          with types;
          submodule {
            options = {
              db = mkOption {
                type = str;
                description = "Name of the database.";
              };

              host = mkOption {
                type = str;
                description = "Host of the database.";
              };

              password = mkOption {
                type = str;
                description = "Password of the database.";
              };

              user = mkOption {
                type = str;
                description = "User of the database.";
              };
            };
          };

        description = "Config of the upstream metrics.";
      }
      // defaultValue "metricsConfig";

    voteAccount = mkOption {
      type = types.str;
      description = "Public key of the vote account the validator votes on behalf of.";
    };

    votingIdentityPath = mkOption {
      type = types.str;
      description = "Path to the voting identity keypair of the validator.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = optionals cfg.rpc.publish [
        cfg.rpc.port
        (cfg.rpc.port + 1)
      ];
    };

    users = {
      users = optionalAttrs (cfg.user == "solana") {
        solana = {
          inherit (cfg) group;

          description = "Solana user";
          uid = 500; # TODO: Maybe upstream?
        };
      };

      groups = optionalAttrs (cfg.group == "solana") { solana.gid = 500; };
    };
  };
}
