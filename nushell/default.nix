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
      default = { };
      description = "Shell aliases for nushell";
    };

    ohMyPoshTheme = lib.mkOption {
      type = lib.types.str;
      default = "peru";
      description = "Oh-my-posh theme name";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      nushell = {
        enable = true;
        shellAliases = {
          ll = "${pkgs.eza}/bin/eza -la";
        }
        // cfg.shellAliases;

        settings = {
          show_banner = false;
          rm.always_trash = true;
        };

        extraEnv =
          let
            envVars = {
              LC_ALL = "en_US.UTF-8";
              SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
            }
            // config.home.sessionVariables;
            envVarLines = lib.mapAttrsToList (name: value: ''$env.${name} = "${value}"'') envVars;
            pathPrepend =
              lib.optionalString (config.home.sessionPath != [ ])
                "$env.PATH = ($env.PATH | prepend [${
                  lib.concatMapStringsSep " " (p: ''"${p}"'') config.home.sessionPath
                }])";
          in
          lib.concatStringsSep "\n" (envVarLines ++ [ pathPrepend ]);

        extraConfig = builtins.readFile ./config.nu;
      };

      atuin = {
        enable = true;
        enableNushellIntegration = false;
        enableBashIntegration = true;
        settings = {
          sync_frequency = "5m";
          network_timeout = 30;
          network_connect_timeout = 5;
          local_timeout = 5;
        };
      };

      zoxide = {
        enable = true;
        enableNushellIntegration = false;
        enableBashIntegration = true;
      };

      oh-my-posh = {
        enable = true;
        enableNushellIntegration = true;
        useTheme = cfg.ohMyPoshTheme;
      };

      carapace = {
        enable = true;
        enableNushellIntegration = true;
      };

      bash = {
        enable = true;
        enableCompletion = true;
        # Source home-manager session vars in interactive shells (not just login shells)
        initExtra = ''
          . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
        '';
      };
    };

    home.file.".local/share/atuin/init.nu".source = ./atuin-init.nu;
  };
}
