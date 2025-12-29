{ config, lib, ... }:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;

  getFormatterCommand =
    name: formatter:
    if formatter.command != "" then formatter.command else "${formatter.package}/bin/${name}";

  getLangServers = langName: lib.attrNames (langCfg.languages.${langName}.servers or { });

  getLangFormatter = langName: langCfg.languages.${langName}.formatter or null;

  getLangDebugger = langName: langCfg.languages.${langName}.debugger or null;
in
{
  options.programs.helix-extended = {
    enable = lib.mkEnableOption "extended helix configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = true;

      settings = {
        theme = "ao";

        editor = {
          completion-replace = true;
          lsp = {
            display-progress-messages = true;
          };
          # line-number = "relative";
          # gutters = [
          #   "diff"
          #   "diagnostics"
          #   "line-numbers"
          #   "spacer"
          # ];
          auto-format = true;

          # auto-save = {
          #   enable = true;
          #   focus-lost = true;
          #   after-delay = {
          #     enable = true;
          #     timeout = 1000;
          #   };
          # };
          bufferline = "multiple";
          indent-guides = {
            render = true;
          };
          end-of-line-diagnostics = "hint";
          inline-diagnostics = {
            cursor-line = "warning";
            other-lines = "error";
          };

          soft-wrap = {
            enable = true;
          };

          shell = [
            "nu"
            "--login"
            "-c"
          ];

        };

        keys = {
          insert = {
            S-tab = "move_parent_node_start";
          };

          select = {
            tab = "extend_parent_node_end";
            S-tab = "extend_parent_node_start";

          };
          normal = {
            tab = "move_parent_node_end";
            S-tab = "move_parent_node_start";
            S-l = ":buffer-next";
            S-h = ":buffer-previous";
            space = {
              B = ''
                :echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}
              '';
              N = ":run-shell-command ${./helix-copy-filename.nu} %{buffer_name}";
            };
          };
        };
      };

      languages = {
        language =
          let
            # Map from languages.nix names to helix language identifiers
            langNameMap = {
              nushell = "nu";
            };

            mkLanguageConfig =
              langName: langConfig:
              let
                helixLangName = langNameMap.${langName} or langName;
                formatter = getLangFormatter langName;
                formatterName =
                  if formatter != null then formatter.package.pname or formatter.package.name else null;
                debugger = getLangDebugger langName;
              in
              {
                name = helixLangName;
                auto-format = true;
                language-servers = getLangServers langName;
              }
              // lib.optionalAttrs (langConfig.scope != null) { inherit (langConfig) scope; }
              // lib.optionalAttrs (langConfig.fileTypes != [ ]) {
                file-types = langConfig.fileTypes;
              }
              // lib.optionalAttrs (langConfig.roots != [ ]) { inherit (langConfig) roots; }
              // lib.optionalAttrs (formatter != null) {
                formatter.command = getFormatterCommand formatterName formatter;
                formatter.args = formatter.args ++ lib.optional (langName == "markdown") helixLangName;
              }
              // lib.optionalAttrs (debugger != null && debugger.enable) {
                debugger = {
                  inherit (debugger) name transport command;
                  inherit (debugger) templates;
                }
                // lib.optionalAttrs (debugger.args != [ ]) {
                  inherit (debugger) args;
                };
              };

            enabledLanguages = lib.filterAttrs (_: l: l.enable) langCfg.languages;
          in
          lib.sortOn (l: l.name) (lib.mapAttrsToList mkLanguageConfig enabledLanguages);

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
                // lib.optionalAttrs (server.args != [ ]) {
                  inherit (server) args;
                }
                // lib.optionalAttrs (server.config != { }) {
                  inherit (server) config;
                }
              );

            allServers = lib.foldl' (acc: langCfg: acc // langCfg.servers) { } (
              lib.attrValues (lib.filterAttrs (_: l: l.enable) langCfg.languages)
            );

            enabledServers = lib.filterAttrs (_: s: s.enable) allServers;
          in
          lib.mapAttrs' mkServerConfig enabledServers;
      };
    };

    programs.languages.enable = true;
  };
}
