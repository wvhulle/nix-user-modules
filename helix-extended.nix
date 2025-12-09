{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;

  getFormatterCommand =
    name: formatter:
    if formatter.command != "" then formatter.command else "${formatter.package}/bin/${name}";

  getLangServers = langName: lib.attrNames (langCfg.languages.${langName}.servers or { });

  getLangFormatter = langName: langCfg.languages.${langName}.formatter or null;
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
        language =
          let
            mdFormatter = getLangFormatter "markdown";
            nixFormatter = getLangFormatter "nix";
            nuFormatter = getLangFormatter "nushell";
          in
          lib.sortOn (l: l.name) (
            [
              {
                name = "markdown";
                auto-format = cfg.enableAutoFormat;
                language-servers = getLangServers "markdown";
                formatter = lib.mkIf (mdFormatter != null) {
                  command = getFormatterCommand "dprint" mdFormatter;
                  args = mdFormatter.args ++ [ "md" ];
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
                name = "nix";
                auto-format = cfg.enableAutoFormat;
                language-servers = getLangServers "nix";
                formatter = lib.mkIf (nixFormatter != null) {
                  command = getFormatterCommand "nixfmt" nixFormatter;
                };
              }

              {
                name = "nu";
                auto-format = cfg.enableAutoFormat;
                language-servers = getLangServers "nushell";
                formatter = lib.mkIf (nuFormatter != null) {
                  command = getFormatterCommand "topiary" nuFormatter;
                  args = nuFormatter.args ++ [ "nu" ];
                };
              }

              {
                name = "rust";
                language-servers = getLangServers "rust";
              }

              {
                name = "typst";
                language-servers = getLangServers "typst";
              }
            ]
            ++ cfg.additionalLanguages
          );

        language-server =
          let
            getServerCommand =
              name: server:
              if server.command != "" then
                server.command
              else if server.package != null then
                "${server.package}/bin/${name}"
              else
                null;

            mkServerConfig =
              name: server:
              let
                cmd = getServerCommand name server;
              in
              lib.nameValuePair name (
                lib.optionalAttrs (cmd != null) { command = cmd; }
                // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; }
                // lib.optionalAttrs (server.config != { }) { inherit (server) config; }
              );

            allServers = lib.foldl' (acc: langCfg: acc // langCfg.servers) { } (
              lib.attrValues (lib.filterAttrs (_: l: l.enable) langCfg.languages)
            );

            enabledServers = lib.filterAttrs (_: s: s.enable) allServers;
          in
          lib.mapAttrs' mkServerConfig enabledServers // cfg.additionalLanguageServers;
      };
    };

    programs.languages.enable = true;
  };
}
