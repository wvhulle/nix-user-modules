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

    shellAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        ll = "${pkgs.eza}/bin/eza -la";
        hm = "home-manager switch --flake /etc/nixos -b backup";
        nr = "sudo nixos-rebuild switch --flake /etc/nixos";
      };
      description = "Shell aliases for nushell";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        LC_ALL = "en_US.UTF-8";
        SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
      };
      description = "Environment variables to set in nushell env.nu";
      example = {
        PAGER = "less";
      };
    };

    additionalPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional paths to prepend to PATH in nushell";
      example = [
        "/home/user/.cargo/bin"
        "/home/user/.local/bin"
      ];
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
            sync_frequency = "5m";
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

        inherit (cfg) shellAliases;

        settings = {
          show_banner = false;
          rm = {
            always_trash = true;
          };
        };

        extraEnv =
          let
            allEnvVars = cfg.environmentVariables // config.home.sessionVariables;

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
          pathPrepend + "\n" + builtins.readFile ./config.nu;
      };

      atuin = lib.mkIf cfg.shellIntegrations.atuin.enable {
        enable = true;
        enableNushellIntegration = false;
        inherit (cfg.shellIntegrations.atuin) settings;
      };

      zoxide = lib.mkIf cfg.shellIntegrations.zoxide.enable {
        enable = true;
        enableNushellIntegration = false;
        enableBashIntegration = true;
      };

      oh-my-posh = lib.mkIf cfg.shellIntegrations.ohMyPosh.enable {
        enable = true;
        enableNushellIntegration = true;
        useTheme = cfg.shellIntegrations.ohMyPosh.theme;
      };

      carapace = {
        enable = true;
        enableNushellIntegration = true;
      };

    };

    home.file.".local/share/atuin/init.nu" = lib.mkIf cfg.shellIntegrations.atuin.enable {
      source = ./atuin-init.nu;
    };
  };
}
