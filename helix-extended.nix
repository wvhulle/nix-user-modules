{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.helix-extended;
  lspCfg = config.programs.lsp;

  getServerCommand =
    name: server: if server.command != "" then server.command else "${server.package}/bin/${name}";

  getFormatterCommand =
    name: formatter:
    if formatter.command != "" then formatter.command else "${formatter.package}/bin/${name}";
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
        language = lib.sortOn (l: l.name) (
          [
            # Markdown
            {
              name = "markdown";
              auto-format = cfg.enableAutoFormat;
              language-servers = [ "typos-lsp" ];
              formatter = {
                command = getFormatterCommand "dprint" lspCfg.formatters.dprint;
                args = lspCfg.formatters.dprint.args ++ [ "md" ];
              };
              auto-pairs = {
                "\"" = ''"'';
                "(" = ")";
                "<" = ">";
                "[" = "]";
                "{" = "}";
              };
            }

            # Nix
            {
              name = "nix";
              auto-format = cfg.enableAutoFormat;
              language-servers = [
                "nil"
                "typos-lsp"
              ];
              formatter.command = getFormatterCommand "nixfmt" lspCfg.formatters.nixfmt;
            }

            # Nushell
            {
              name = "nu";
              auto-format = cfg.enableAutoFormat;
              language-servers = [
                "nu-lint"
                "typos-lsp"
              ];
              formatter = {
                command = getFormatterCommand "topiary" lspCfg.formatters.topiary;
                args = lspCfg.formatters.topiary.args ++ [ "nu" ];
              };
            }

            # Rust
            {
              name = "rust";
              language-servers = [
                "rust-analyzer"
                "typos-lsp"
              ];
            }

            # Typst
            {
              name = "typst";
              language-servers = [
                "tinymist"
                "typos-lsp"
              ];
            }
          ]
          ++ cfg.additionalLanguages
        );

        language-server =
          let
            mkServerConfig =
              name: server:
              lib.nameValuePair name (
                {
                  command = getServerCommand name server;
                }
                // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; }
                // lib.optionalAttrs (server.config != { }) { inherit (server) config; }
              );
            enabledServers = lib.filterAttrs (_: s: s.enable) lspCfg.servers;
          in
          lib.mapAttrs' mkServerConfig enabledServers // cfg.additionalLanguageServers;
      };
    };

    programs.lsp.enable = true;
  };
}
