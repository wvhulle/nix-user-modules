{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.keyboard-action;

  # Base monitor script
  monitorScript = pkgs.writers.writeNuBin "keyboard-action-monitor" (
    builtins.readFile ./keyboard-action-monitor.nu
  );

  # Create a wrapper script for a specific key combination
  makeKeyboardMonitor =
    name: actionCfg:
    let
      # Build modifier arguments like "meta:KEY_LEFTMETA:125"
      modifierArgs = lib.filter (key: key.name != actionCfg.triggerKey.name) actionCfg.keys;
      modifierSpecs = map (key: "${key.name}:${key.eventName}:${toString key.code}") modifierArgs;
    in
    pkgs.writeShellScriptBin "keyboard-action-${name}" ''
      exec ${monitorScript}/bin/keyboard-action-monitor \
        "${actionCfg.triggerKey.eventName}" \
        ${lib.concatStringsSep " \\\n        " (map lib.escapeShellArg modifierSpecs)} \
        --action "${actionCfg.action}" \
        --description "${actionCfg.keyDescription}"
    '';

  # Generate systemd services for all configured actions
  keyboardActionServices = lib.mapAttrs' (
    name: actionCfg:
    let
      wrapperScript = makeKeyboardMonitor name actionCfg;
    in
    lib.nameValuePair "keyboard-action-${name}" {
      Unit = {
        Description = "Monitor ${actionCfg.keyDescription} and run action";
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
            keys = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      description = "Variable name for this key (e.g., 'meta', 'shift', 'f23')";
                      example = "meta";
                    };
                    eventName = lib.mkOption {
                      type = lib.types.str;
                      description = "Linux event name (e.g., 'KEY_LEFTMETA', 'KEY_F23')";
                      example = "KEY_LEFTMETA";
                    };
                    code = lib.mkOption {
                      type = lib.types.int;
                      description = "Linux input event code";
                      example = 125;
                    };
                  };
                }
              );
              description = "List of all keys involved (including modifiers and trigger key)";
            };

            triggerKey = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Variable name for the trigger key (must match one from keys list)";
                  };
                  eventName = lib.mkOption {
                    type = lib.types.str;
                    description = "Linux event name for the trigger key";
                  };
                };
              };
              description = "The key whose release triggers the action";
            };

            keyDescription = lib.mkOption {
              type = lib.types.str;
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
