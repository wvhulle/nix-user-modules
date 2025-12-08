{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.helix-extended;
in
{
  options.programs.helix-extended = {
    enable = lib.mkEnableOption "extended helix configuration";

    setAsDefaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to set helix as the default editor (EDITOR environment variable)";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "ao";
      description = "Helix theme to use";
      example = "onedark";
    };

    enableAutoFormat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable auto-formatting";
    };

    enableAutoSave = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable auto-save functionality";
    };

    autoSaveTimeout = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Auto-save timeout in milliseconds";
    };

    enableLanguageServers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable language server configurations";
    };

    additionalLanguages = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Additional language configurations";
    };

    additionalLanguageServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Additional language server configurations";
    };

    customKeybinds = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Custom key bindings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = cfg.setAsDefaultEditor;

      settings = {
        inherit (cfg) theme;

        editor = {
          gutters = [
            "diff"
            "diagnostics"
            "line-numbers"
            "spacer"
          ];
          auto-format = cfg.enableAutoFormat;

          auto-save = lib.mkIf cfg.enableAutoSave {
            enable = true;
            focus-lost = true;
            after-delay = {
              enable = true;
              timeout = cfg.autoSaveTimeout;
            };
          };

          indent-guides = {
            render = true;
          };

          inline-diagnostics = {
            cursor-line = "warning";
            other-lines = "disable";
          };

          lsp = {
            display-inlay-hints = false;
          };

          soft-wrap = {
            enable = true;
          };
        };

        keys = cfg.customKeybinds;
      };

      languages = lib.mkIf cfg.enableLanguageServers {
        language = [
          {
            name = "nix";
            auto-format = cfg.enableAutoFormat;
            formatter = {
              command = "${pkgs.nixfmt-classic}/bin/nixfmt";
            };
          }
          {
            name = "nu";
            auto-format = cfg.enableAutoFormat;
            language-servers = [ "nu-lint" ];
            formatter = {
              command = "${pkgs.topiary}/bin/topiary";
              args = [
                "format"
                "--language"
                "nu"
              ];
            };
          }
          {
            name = "markdown";
            auto-format = cfg.enableAutoFormat;
            formatter = {
              command = "${pkgs.dprint}/bin/dprint";
              args = [
                "fmt"
                "--stdin"
                "md"
              ];
            };
            auto-pairs = {
              "\"" = ''"'';
              "(" = ")";
              "<" = ">";
              "[" = "]";
              "{" = "}";
            };
          }
          {
            name = "rust";
            language-servers = [ "rust-analyzer" ];
          }
        ]
        ++ cfg.additionalLanguages;

        language-server = {
          nu-lint = {
            command = "nu-lint";
            args = [ "--lsp" ];
          };
          rust-analyzer = {
            config = {
              cargo = {
                allFeatures = true;
                allTargets = false;
              };
              check = {
                command = "clippy";
                # extraArgs = [
                #   "--"
                #   "-W"
                #   "clippy::pedantic"
                # ];
              };
            };
          };
        }
        // cfg.additionalLanguageServers;
      };
    };
  };
}
