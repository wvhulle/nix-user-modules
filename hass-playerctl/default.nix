{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.hass-playerctl;
in
{
  options.programs.hass-playerctl = {
    enable = lib.mkEnableOption "HTTP bridge for Home Assistant to control desktop media players via playerctl";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8553;
      description = "Port for the HTTP server";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.hass-playerctl = {
      Unit = {
        Description = "HTTP bridge for playerctl (Home Assistant)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${pkgs.python3}/bin/python3 ${./hass-playerctl-server.py} ${toString cfg.port}";
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.playerctl ]}"
        ];

        # Hardening
        LockPersonality = true;
        NoNewPrivileges = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
