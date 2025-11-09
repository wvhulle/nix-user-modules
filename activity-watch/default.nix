{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.programs.activitywatch;
  defaultCategories = import ./categories.nix;

  flattenCategories =
    categories:
    lib.mapAttrsToList (
      name: value:
      {
        name = [ name ];
        rule = {
          type = if (value.regex or null) != null then "regex" else "none";
        }
        // lib.optionalAttrs ((value.regex or null) != null) { inherit (value) regex; };
      }
      // lib.optionalAttrs ((value.keywords or null) != null) {
        rule = {
          type = "regex";
          regex = lib.concatStringsSep "|" value.keywords;
        };
      }
      // lib.optionalAttrs ((value.color or null) != null) { data = { inherit (value) color; }; }
      // lib.optionalAttrs ((value.score or null) != null) { data.score = value.score; }
      // lib.optionalAttrs ((value.children or null) != null) {
        children = lib.flatten (
          lib.mapAttrsToList (
            childName: childValue:
            let
              childCategory = flattenCategories { ${childName} = childValue; };
            in
            map (child: child // { name = [ name ] ++ child.name; }) childCategory
          ) value.children
        );
      }
    ) categories;

  categoriesJson = pkgs.writeText "categories.json" (
    builtins.toJSON (lib.flatten (flattenCategories cfg.categories))
  );

  categoriesImportScript = pkgs.writers.writeNuBin "aw-import-categories" ''
    ^curl -X POST -H "Content-Type: application/json" -d $"@${categoriesJson}" $"http://localhost:${toString cfg.server.port}/api/0/settings/classes"
    print "Categories imported successfully!"
  '';

  configFile = pkgs.writeText "aw-server-rust-config.toml" ''
    cors = ${builtins.toJSON cfg.server.corsOrigins}
  '';

  createConfigScript = pkgs.writers.writeNuBin "create-config-dirs" ''
    let config_dir = $"($env.HOME)/.config/activitywatch/aw-server-rust"
    ^mkdir -p $config_dir
    ^rm -f $"($config_dir)/config.toml"
    ^cp ${configFile} $"($config_dir)/config.toml"
  '';
in
{
  options.programs.activitywatch = {
    enable = lib.mkEnableOption "ActivityWatch client and server";

    server = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable ActivityWatch server";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5600;
        description = "Port on which ActivityWatch server listens";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Host address on which ActivityWatch server listens";
      };

      corsOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "http://localhost:5600"
          "http://127.0.0.1:5600"
        ];
        description = "List of allowed CORS origins for ActivityWatch server";
      };
    };

    categories = lib.mkOption {
      type = lib.types.attrs;
      default = defaultCategories;
      description = "Activity categorization rules";
      example = lib.literalExpression ''
        {
          Work = {
            regex = "Google Docs|libreoffice";
            color = "#2E7D32";
            score = 10;
            children = {
              Programming = {
                keywords = [ "GitHub" "vim" "Code" ];
                color = "#1565C0";
              };
            };
          };
        }
      '';
    };

    importCategories = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically import categories on service start";
    };

    watchers = {
      afk = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable AFK (Away From Keyboard) watcher";
      };

      window = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable window title watcher for Wayland";
      };

      vscode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable VSCode extension for ActivityWatch";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install core ActivityWatch packages
    home.packages = with pkgs; [
      activitywatch
      aw-watcher-afk
      aw-notify
      awatcher
    ];

    # User systemd services for ActivityWatch components
    systemd.user.services = {
      # ActivityWatch server
      activitywatch-server = lib.mkIf cfg.server.enable {
        Unit = {
          Description = "ActivityWatch server";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          Type = "simple";
          ExecStartPre = "${createConfigScript}/bin/create-config-dirs";
          ExecStart = "${pkgs.activitywatch}/bin/aw-server --host ${cfg.server.host} --port ${toString cfg.server.port}";
          Restart = "always";
          RestartSec = "5";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      # Categories import service
      activitywatch-import-categories =
        lib.mkIf (cfg.server.enable && cfg.importCategories && cfg.categories != { })
          {
            Unit = {
              Description = "Import ActivityWatch categories";
              After = [ "activitywatch-server.service" ];
              Wants = [ "activitywatch-server.service" ];
              Requisite = [ "activitywatch-server.service" ];
            };

            Service = {
              Type = "oneshot";
              RemainAfterExit = false;
              ExecStart = "${categoriesImportScript}/bin/aw-import-categories";
              Restart = "on-failure";
              RestartSec = "10";
            };

            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };

      # Wayland window title watcher
      activitywatch-watcher-window = lib.mkIf cfg.watchers.window {
        Unit = {
          Description = "ActivityWatch Wayland window title watcher";
          After = [
            "graphical-session.target"
            "activitywatch-server.service"
          ];
          PartOf = [ "graphical-session.target" ];
          Wants = lib.mkIf cfg.server.enable [ "activitywatch-server.service" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.awatcher}/bin/awatcher";
          Restart = "always";
          RestartSec = "5";
          # Keep trying to restart even after failures
          RestartForceExitStatus = [
            1
            2
            8
          ];
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      # AFK watcher
      activitywatch-watcher-afk = lib.mkIf cfg.watchers.afk {
        Unit = {
          Description = "ActivityWatch AFK watcher";
          After = [
            "graphical-session.target"
            "activitywatch-server.service"
          ];
          PartOf = [ "graphical-session.target" ];
          Wants = lib.mkIf cfg.server.enable [ "activitywatch-server.service" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.aw-watcher-afk}/bin/aw-watcher-afk";
          Restart = "always";
          RestartSec = "5";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };

    # VSCode extension configuration
    programs.vscode-extended = lib.mkIf cfg.watchers.vscode {
      additionalMarketplaceExtensions = [
        {
          name = "aw-watcher-vscode";
          publisher = "activitywatch";
          version = "0.5.0";
          sha256 = "OrdIhgNXpEbLXYVJAx/jpt2c6Qa5jf8FNxqrbu5FfFs=";
        }
      ];
    };
  };
}
