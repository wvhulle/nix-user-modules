# Solar-based brightness control - Hardware agnostic
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.solar-brightness;

  brightnessScript = pkgs.writers.writeNuBin "solar-brightness-manager" (
    builtins.readFile ./solar-brightness-manager.nu
  );
in
{
  options.programs.solar-brightness = {
    enable = lib.mkEnableOption "Solar-based brightness control";

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

    transition = {
      max-step = lib.mkOption {
        type = lib.types.float;
        default = 0.05;
        description = "Maximum brightness change per transition step (0.0-1.0, default 0.05 = 5%)";
      };

      step-delay = lib.mkOption {
        type = lib.types.int;
        default = 200;
        description = "Delay in milliseconds between transition steps";
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
        ExecStart = "${brightnessScript}/bin/solar-brightness-manager --min-brightness ${toString cfg.min-brightness} --max-brightness ${toString cfg.max-brightness} --latitude ${toString cfg.location.latitude} --longitude ${toString cfg.location.longitude} --twilight-type ${cfg.twilight-type} --solar-offset ${toString cfg.solar-offset} --transition-max-step ${toString cfg.transition.max-step} --transition-step-delay ${toString cfg.transition.step-delay}";
        SyslogLevelPrefix = true;
        StandardOutput = "journal";
        StandardError = "journal";
        Path = with pkgs; [
          heliocron
          bash
          ddcutil # For DDC/CI backend
          bc # For calculations
          coreutils # For backlight backend
        ];
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
        OnCalendar = cfg.interval;
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    home.packages = with pkgs; [
      heliocron
      ddcutil # For external monitors
    ];
  };
}
