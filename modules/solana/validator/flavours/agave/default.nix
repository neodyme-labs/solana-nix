{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkOverride
    optional
    optionalAttrs
    optionals
    types
    ;

  cfg = config.services.solana-validator;
  agaveCfg = cfg.agave;

  logfileScript = pkgs.writeShellScript "rotate-validator-log.sh" (
    builtins.readFile ./scripts/validator-log.sh
  );

  validatorCmd = "${cfg.package}/bin/agave-validator";
in
{
  options.services.solana-validator = {
    flavour = mkOption { type = types.enum [ "agave" ]; };

    agave = {
      accountsDbPath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/accounts-db";
        description = "Path of the accounts db.";
      };

      accountsDbTmpfs = {
        enable = mkEnableOption "accounts db on tmpfs";

        size = mkOption {
          type = types.str;
          description = "Size of the tmpfs to create for the accounts db.";
        };
      };

      accountHashCachePath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/account-hash-cache";
        description = "Path of the account hash cache.";
      };

      accountIndexPaths = mkOption {
        type = with types; nullOr (listOf str);
        default = [ "${cfg.dataDir}/account-index" ];
        defaultText = literalExpression "${cfg.dataDir}/account-index";
        description = "Paths to at which to place the account indexes.";
      };

      dynamicPortRange = {
        from = mkOption {
          type = types.port;
          default = 8000;
          description = "Dynamic port range start.";
        };

        to = mkOption {
          type = types.port;
          default = agaveCfg.dynamicPortRange.from + 20;
          defaultText = literalExpression "from + 20";
          description = "Dynamic port range end.";
        };
      };

      enableGenesisFetch = mkEnableOption "genesis fetching";
      enableSnapshotFetch = mkEnableOption "snapshots fetching";

      extraFlags = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "Extra arguments passed to agave.";
      };

      fullSnapshotInterval = mkOption {
        type = with types; nullOr ints.unsigned;
        default = null;
        description = "Interval in slots to pass as full snapshot interval.";
      };

      incrementalSnapshotInterval = mkOption {
        type = with types; nullOr ints.unsigned;
        default = null;
        description = "Interval in slots to pass as snapshot interval.";
      };

      jitoSupport = mkOption {
        type = types.bool;
        default = cfg.package.solana.jitoSupport or false;
        defaultText = "Passthru value `solana.jitoSupport` of the package.";
        description = "Whether the validator supports jito";
      };

      ledgerPath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/ledger";
        description = "Path to the ledger.";
      };

      limitLedgerSize = mkEnableOption "ledger size limiting" // {
        default = true;
      };

      openFirewall = mkEnableOption "opening of the firewall." // {
        default = true;
      };

      rpc = {
        onlyKnown = mkEnableOption "using the RPC of known validators only" // {
          default = true;
        };

        full = mkEnableOption "full RPC (chain state and transaction history)";
        transactionHistory = mkEnableOption "historical transactions (will increase disk usage and IOPS)";
      };

      snapshotsPath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/snapshots";
        description = "Path to the snapshots.";
      };

      walRecoveryMode = mkOption {
        type = types.str;
        default = "skip_any_corrupted_record";
        description = "WAL recovery mode.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.flavour == "agave") {
    boot.kernel.sysctl = {
      "net.core.rmem_default" = mkDefault 134217728;
      "net.core.rmem_max" = mkDefault 134217728;
      "net.core.wmem_default" = mkDefault 134217728;
      "net.core.wmem_max" = mkDefault 134217728;
      "vm.max_map_count" = mkOverride 999 2097152;
    };

    environment = {
      systemPackages = [ cfg.package ];
    };

    fileSystems = mkIf agaveCfg.accountsDbTmpfs.enable {
      ${agaveCfg.accountsDbPath} = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "mode=0755"
          "size=${agaveCfg.accountsDbTmpfs.size}"
          "uid=${cfg.user}"
          "gid=${cfg.group}"
        ];
      };
    };

    networking.firewall = mkIf cfg.openFirewall rec {
      allowedUDPPortRanges = [ { inherit (agaveCfg.dynamicPortRange) from to; } ];
      allowedTCPPortRanges = allowedUDPPortRanges;
    };

    systemd = {
      services = mkMerge (
        [
          {
            agave-validator = {
              description = "Agave Validator";
              stopIfChanged = mkDefault cfg.restartIfChanged;
              restartIfChanged = mkDefault cfg.restartIfChanged;

              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];

              unitConfig.RequiresMountsFor = [
                cfg.dataDir
                cfg.logDir
              ];

              environment = optionalAttrs cfg.enableUpstreamMetrics {
                SOLANA_METRICS_CONFIG = concatStringsSep "," [
                  "host=${cfg.upstreamMetricsConfig.host}"
                  "db=${cfg.upstreamMetricsConfig.db}"
                  "u=${cfg.upstreamMetricsConfig.user}"
                  "p=${cfg.upstreamMetricsConfig.password}"
                ];
              };

              serviceConfig = mkMerge (
                [
                  {
                    ExecStartPre = "${logfileScript} \"${cfg.logDir}\" \"${cfg.logDir}/solana-validator.log\"";

                    ExecStart =
                      "${cfg.package}/bin/agave-validator "
                      + concatStringsSep " " (
                        [
                          "--identity ${escapeShellArg cfg.identityPath}"
                          "--accounts ${escapeShellArg agaveCfg.accountsDbPath}"
                          "--ledger ${escapeShellArg agaveCfg.ledgerPath}"
                          "--snapshots ${escapeShellArg agaveCfg.snapshotsPath}"
                          "--accounts-hash-cache-path ${escapeShellArg agaveCfg.accountHashCachePath}"
                          "--log ${escapeShellArg cfg.logDir}/solana-validator.log"
                          "--rpc-port ${toString cfg.rpc.port}"
                          "--expected-genesis-hash ${escapeShellArg cfg.genesisHash}"
                          "--wal-recovery-mode ${escapeShellArg agaveCfg.walRecoveryMode}"
                        ]
                        ++ optionals (agaveCfg.accountIndexPaths != null) (
                          map (e: "--accounts-index-path ${escapeShellArg e}") agaveCfg.accountIndexPaths
                        )
                        ++ map (v: "--known-validator ${escapeShellArg v}") cfg.trustedValidators
                        ++ map (v: "--entrypoint ${escapeShellArg v}") cfg.entrypoints
                        ++ optional (
                          cfg.rpc.listenAddress != null
                        ) "--rpc-bind-address ${escapeShellArg cfg.rpc.listenAddress}"
                        ++ optional (
                          agaveCfg.fullSnapshotInterval != null
                        ) "--full-snapshot-interval-slots ${toString agaveCfg.fullSnapshotInterval}"
                        ++ optional (
                          agaveCfg.incrementalSnapshotInterval != null
                        ) "--snapshot-interval-slots ${toString agaveCfg.incrementalSnapshotInterval}"
                        ++ optional agaveCfg.limitLedgerSize "--limit-ledger-size"
                        ++ optional agaveCfg.rpc.onlyKnown "--only-known-rpc"
                        ++ optional (!cfg.rpc.publish) "--private-rpc"
                        ++ optional (!cfg.enableVoting) "--no-voting"
                        ++ optional (!agaveCfg.enableGenesisFetch) "--no-genesis-fetch"
                        ++ optional (!agaveCfg.enableSnapshotFetch) "--no-snapshot-fetch"
                        ++ optional cfg.enableVoting "--vote-account ${escapeShellArg cfg.voteAccount}"
                        ++ optional agaveCfg.rpc.full "--full-rpc-api"
                        ++ optional agaveCfg.rpc.transactionHistory "--enable-rpc-transaction-history"
                        ++ optionals (cfg.jito.enable && agaveCfg.jitoSupport) [
                          "--tip-payment-program-pubkey ${escapeShellArg cfg.jito.tipPaymentProgram}"
                          "--tip-distribution-program-pubkey ${escapeShellArg cfg.jito.tipDistributionProgram}"
                          "--merkle-root-upload-authority ${escapeShellArg cfg.jito.merkleRootUploadAuthority}"
                          "--commission-bps ${toString cfg.jito.commissionBps}"
                          "--relayer-url ${escapeShellArg cfg.jito.relayerURL}"
                          "--block-engine-url ${escapeShellArg cfg.jito.blockEngineURL}"
                          "--shred-receiver-address ${escapeShellArg cfg.jito.shredReceiverAddress}"
                        ]
                        ++ agaveCfg.extraFlags
                      );

                    # Limits
                    LimitNOFILE = "1000000";

                    # User and group
                    User = cfg.user;
                    Group = cfg.group;

                    # Capabilities
                    CapabilityBoundingSet = "";
                    NoNewPrivileges = true;

                    # Sandboxing (sorted by occurrence in https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
                    ProtectSystem = "strict";
                    ProtectHome = true;
                    PrivateTmp = true;
                    PrivateDevices = true;
                    ProtectHostname = true;
                    ProtectClock = true;
                    ProtectKernelModules = true;
                    ProtectKernelLogs = true;
                    ProtectControlGroups = true;
                    RestrictAddressFamilies = [
                      "AF_UNIX"
                      "AF_INET"
                      "AF_INET6"
                    ];
                    LockPersonality = true;
                    RestrictRealtime = true;
                    RestrictSUIDSGID = true;
                    RemoveIPC = true;
                    PrivateMounts = true;
                  }
                ]
                ++ optional (cfg.logDir == "/var/log/solana") {
                  LogsDirectory = "solana";
                  LogsDirectoryMode = "0755";
                }
                ++ optional (cfg.dataDir == "/var/lib/solana") {
                  StateDirectory = "solana";
                  StateDirectoryMode = "0755";
                }
              );
            };
          }
        ]
        ++ optional cfg.logCleanup.enable {
          agave-validator-logrotate = {
            description = "Agave Validator Log Rotation";

            after = [ "agave-validator.service" ];
            requisite = [ "agave-validator.service" ];

            serviceConfig = {
              Type = "oneshot";
              Restart = "no";

              ExecStart = pkgs.writeShellScript "rotate-validator-log.sh" ''
                set -euo pipefail

                echo "rotating file"
                ${logfileScript} "${cfg.logDir}" "${cfg.logDir}/solana-validator.log"

                echo "changing new file owner"
                chown --dereference ${cfg.user}:${cfg.group} "${cfg.logDir}/solana-validator.log"

                echo "notifying validator"
                ${lib.getExe' pkgs.systemd "systemctl"} kill -s USR1 agave-validator.service
              '';
            };
          };
        }
        ++ optional cfg.enableVoting {
          agave-validator-voting = {
            description = "Agave Validator Voting";
            stopIfChanged = mkDefault cfg.restartIfChanged;
            restartIfChanged = mkDefault cfg.restartIfChanged;

            after = [ "agave-validator.service" ];
            requisite = [ "agave-validator.service" ];

            serviceConfig = {
              Type = "oneshot";
              Restart = "no";
              RemainAfterExit = true;

              ExecStart = pkgs.writeShellScript "enable-agave-validator-voting.sh" ''
                set -euo pipefail

                echo "Enabling voting"
                ${validatorCmd} --ledger ${escapeShellArg agaveCfg.ledgerPath} set-identity --require-tower "${cfg.votingIdentityPath}"
                ${validatorCmd} --ledger ${escapeShellArg agaveCfg.ledgerPath} authorized-voter add "${cfg.votingIdentityPath}"
              '';

              ExecStop = pkgs.writeShellScript "disable-agave-validator-voting.sh" ''
                echo "Disabling voting"
                ${validatorCmd} --ledger ${escapeShellArg agaveCfg.ledgerPath} authorized-voter remove-all
                ${validatorCmd} --ledger ${escapeShellArg agaveCfg.ledgerPath} set-identity "${cfg.identityPath}"
              '';
            };
          };
        }
      );

      timers = mkIf cfg.logCleanup.enable {
        agave-validator-logrotate = {
          inherit (config.systemd.services.agave-validator-logrotate) description;

          upheldBy = [ "agave-validator.service" ];
          timerConfig.OnCalendar = cfg.logCleanup.reloadCalendar;
        };
      };

      tmpfiles.rules =
        optional cfg.logCleanup.enable "e ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} ${cfg.logCleanup.retention}"
        ++ optional agaveCfg.accountsDbTmpfs.enable "D! ${escapeShellArg agaveCfg.snapshotsPath}/snapshots 0755 ${cfg.user} ${cfg.group}";
    };
  };
}
