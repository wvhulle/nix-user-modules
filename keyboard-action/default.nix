{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.keyboard-action;

  normalizeKeyName =
    key:
    let
      upper = lib.toUpper key;
    in
    if lib.hasPrefix "KEY_" upper then upper else "KEY_${upper}";

  formatModifierArgs = lib.concatMapStringsSep " " (m: ''"${normalizeKeyName m}"'');

  makeKeyboardMonitor =
    name: actionCfg:
    pkgs.writers.writeNuBin "keyboard-action-${name}" ''
      (nu ${./keyboard-action-monitor.nu}
        "${normalizeKeyName actionCfg.triggerKey}"
        ${formatModifierArgs actionCfg.modifiers}
        --action "${actionCfg.action}"
        ${
          lib.optionalString (actionCfg.description != null) ''--description "${actionCfg.description}"''
        })
    '';

  # Generate systemd services for all configured actions
  keyboardActionServices = lib.mapAttrs' (
    name: actionCfg:
    let
      wrapperScript = makeKeyboardMonitor name actionCfg;
    in
    lib.nameValuePair "keyboard-action-${name}" {
      Unit = {
        Description = "Monitor ${name} and run action";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        ExecStart = "${wrapperScript}/bin/keyboard-action-${name}";
        SyslogLevelPrefix = true;
        StandardOutput = "journal";
        StandardError = "journal";
        Environment = [
          # Include system and user profile paths for launched applications
          "PATH=/run/current-system/sw/bin:${config.home.profileDirectory}/bin:${
            lib.makeBinPath (
              with pkgs;
              [
                evtest
                util-linux
                coreutils
                systemd
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
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    }
  ) cfg.actions;

in
{
  options.programs.keyboard-action = {
    enable = lib.mkEnableOption "keyboard action monitoring";

    actions = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            modifiers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Modifier key names (case-insensitive, KEY_ prefix optional)";
              example = [
                "leftmeta"
                "leftshift"
              ];
            };

            triggerKey = lib.mkOption {
              type = lib.types.str;
              description = "Trigger key name (case-insensitive, KEY_ prefix optional)";
              example = "f23";
            };

            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Human-readable description of the key combination";
              example = "Meta+Shift+F23";
            };

            action = lib.mkOption {
              type = lib.types.str;
              description = "Command to run when key combination is detected";
              example = "kitty";
            };
          };
        }
      );
      default = { };
      description = "Keyboard actions to monitor";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = keyboardActionServices;

    home.packages = with pkgs; [
      evtest
    ];
  };
}
