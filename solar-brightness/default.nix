# Solar-based brightness control - Hardware agnostic
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.solar-brightness;

  # Both Nushell and systemd accept compatible duration formats
  # Common units: sec, min, hr/h, day
in
{
  options.programs.solar-brightness = {
    enable = lib.mkEnableOption "Solar-based brightness control";

    interval-minutes = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Check brightness interval (systemd/nushell duration format: sec, min, hr, day)";
      example = "30min";
    };

    min-brightness = lib.mkOption {
      type = lib.types.float;
      default = 0.1;
      description = "Minimum brightness level (0.0-1.0)";
    };

    max-brightness = lib.mkOption {
      type = lib.types.float;
      default = 0.8;
      description = "Maximum brightness level (0.0-1.0)";
    };

    location = {
      latitude = lib.mkOption {
        type = lib.types.float;
        default = 51.4769;
        description = "Latitude in decimal degrees (positive = north)";
      };

      longitude = lib.mkOption {
        type = lib.types.float;
        default = -5.0e-4;
        description = "Longitude in decimal degrees (positive = east)";
      };
    };

    twilight-type = lib.mkOption {
      type = lib.types.enum [
        "civil"
        "nautical"
        "astronomical"
        "daylight"
      ];
      default = "civil";
      description = "Type of twilight calculation to use for transitions";
    };

    solar-offset = lib.mkOption {
      type = lib.types.str;
      default = "0min";
      description = "Offset duration to adjust solar calculations (e.g., '0sec', '0min', '30min', '1hr')";
      example = "30min";
    };

    transition = {
      max-step = lib.mkOption {
        type = lib.types.float;
        default = 5.0e-2;
        description = "Maximum brightness change per transition step (0.0-1.0, default 0.05 = 5%)";
      };

      step-delay = lib.mkOption {
        type = lib.types.str;
        default = "200ms";
        description = "Delay duration between transition steps (e.g., '200ms', '500ms')";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.solar-brightness = {
      Unit = {
        Description = "Solar-based brightness adjustment";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = lib.concatStringsSep " " [
          "${./solar-brightness-manager.nu}"
          "adjust"
          "--min-brightness ${toString cfg.min-brightness}"
          "--max-brightness ${toString cfg.max-brightness}"
          "--latitude ${toString cfg.location.latitude}"
          "--longitude ${toString cfg.location.longitude}"
          "--twilight-type ${cfg.twilight-type}"
          "--solar-offset ${cfg.solar-offset}"
          "--transition-max-step ${toString cfg.transition.max-step}"
          "--transition-step-delay ${cfg.transition.step-delay}"
        ];
        SyslogIdentifier = "solar-brightness";
        SyslogLevelPrefix = true;
        StandardOutput = "journal";
        StandardError = "journal";
        LogExtraFields = [
          "SERVICE_CONTEXT=solar-brightness"
          "HARDENING_NOTE=ProtectHome=read-only requires ReadWritePaths for caches"
        ];
        Environment = [
          "PATH=${
            lib.makeBinPath (
              with pkgs;
              [
                nushell
                heliocron
                bash
                ddcutil
                brightnessctl
                coreutils
                kdePackages.qttools
              ]
            )
          }"
        ];

        # Hardening
        LockPersonality = true;
        NoNewPrivileges = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        ProtectHome = "read-only";
        ReadWritePaths = [ "%h/.cache/ddcutil" ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.solar-brightness = {
      Unit = {
        Description = "Solar brightness timer";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnUnitActiveSec = cfg.interval-minutes;
        OnBootSec = cfg.interval-minutes;
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    home.packages = with pkgs; [
      heliocron
      ddcutil # For external monitors
      (pkgs.writers.writeNuBin "solar-brightness-manager" (
        builtins.readFile ./solar-brightness-manager.nu
      ))
    ];
  };
}
