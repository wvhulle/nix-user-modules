# Dell U4323QE monitor time-based brightness control
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.dell-brightness;

  brightnessScript = pkgs.writers.writeNuBin "brightness-manager" (
    builtins.readFile ./brightness-manager.nu
  );
in
{
  options.programs.dell-brightness = {
    enable = lib.mkEnableOption "Dell U4323QE solar-based brightness control";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "systemd calendar interval for brightness checks";
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
        default = -0.0005;
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
      type = lib.types.int;
      default = 0;
      description = "Offset in minutes to adjust solar calculations (+/- from calculated times)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.dell-brightness = {
      Unit = {
        Description = "Dell U4323QE brightness adjustment";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${brightnessScript}/bin/brightness-manager --min-brightness ${toString cfg.min-brightness} --max-brightness ${toString cfg.max-brightness} --latitude ${toString cfg.location.latitude} --longitude ${toString cfg.location.longitude} --twilight-type ${cfg.twilight-type} --solar-offset ${toString cfg.solar-offset}";
        # Enable systemd log level prefixes for proper logging
        SyslogLevelPrefix = true;
        StandardOutput = "journal";
        StandardError = "journal";
        # Ensure solar calculation tools are available
        Path = with pkgs; [
          heliocron
          ddcutil
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.dell-brightness = {
      Unit = {
        Description = "Dell U4323QE brightness timer";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    # Ensure solar calculation and monitor control tools are available in user environment
    home.packages = with pkgs; [
      heliocron
      ddcutil
    ];
  };
}
