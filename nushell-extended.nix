{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nushell-extended;

in
{

  options.programs.nushell-extended = {
    enable = lib.mkEnableOption "extended nushell configuration";

    defaultAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to include default shell aliases (ll, tree)";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables to set in nushell env.nu";
      example = {
        EDITOR = "hx";
        PAGER = "less";
      };
    };

    enableCommonDefaults = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable common environment variable defaults (LC_ALL, SSH_AUTH_SOCK)";
    };

    additionalPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional paths to prepend to PATH in nushell (will take precedence over nix store paths)";
      example = [
        "/home/user/.cargo/bin"
        "/home/user/.local/bin"
      ];
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      description = "Username for nushell configuration";
    };

    shellIntegrations = {
      atuin = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable atuin shell history integration";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {
            sync_frequency = "10m";
            network_timeout = 30;
            network_connect_timeout = 5;
            local_timeout = 5;
          };
          description = "Atuin configuration settings";
        };
      };

      zoxide = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable zoxide directory jumping";
        };
      };

      ohMyPosh = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable oh-my-posh prompt theme";
        };
        theme = lib.mkOption {
          type = lib.types.str;
          default = "peru";
          description = "Oh-my-posh theme name";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {

    programs = {
      nushell = {
        enable = true;

        shellAliases = lib.mkIf cfg.defaultAliases {
          ll = "${pkgs.eza}/bin/eza -la";
          tree = "${pkgs.eza}/bin/eza --tree";
        };

        settings = {
          show_banner = false;
          rm = {
            always_trash = true;
          };
        };

        extraEnv =
          let
            allEnvVars =
              cfg.environmentVariables
              // (lib.optionalAttrs cfg.enableCommonDefaults {
                LC_ALL = "en_US.UTF-8";
                SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
              })
              // config.home.sessionVariables;

            envVarLines = lib.mapAttrsToList (name: value: ''$env.${name} = "${value}"'') allEnvVars;
          in
          lib.concatStringsSep "\n" envVarLines;

        extraConfig =
          let
            pathPrepend =
              lib.optionalString (cfg.additionalPaths != [ ])
                "$env.PATH = ($env.PATH | prepend [${
                  lib.concatMapStringsSep " " (p: ''"${p}"'') cfg.additionalPaths
                }])";
          in
          pathPrepend + "\n" + builtins.readFile ./nushell-config.nu;
      };

      atuin = lib.mkIf cfg.shellIntegrations.atuin.enable {
        enable = true;
        enableNushellIntegration = false;
        inherit (cfg.shellIntegrations.atuin) settings;
      };

      zoxide = lib.mkIf cfg.shellIntegrations.zoxide.enable {
        enable = true;
        enableNushellIntegration = false;
      };

      oh-my-posh = lib.mkIf cfg.shellIntegrations.ohMyPosh.enable {
        enable = true;
        enableNushellIntegration = false;
        useTheme = cfg.shellIntegrations.ohMyPosh.theme;
      };
    };

    home.file.".local/share/atuin/init.nu" = lib.mkIf cfg.shellIntegrations.atuin.enable {
      source = ./atuin-init.nu;
    };
  };
}
