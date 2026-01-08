{ config, lib, ... }:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;

  # Well-known language servers that Helix can find by name without explicit path
  builtinServers = [
    "rust-analyzer"
    "clangd"
    "gopls"
    "pylsp"
    "typescript-language-server"
    "vscode-css-language-server"
    "vscode-html-language-server"
    "vscode-json-language-server"
    "yaml-language-server"
    "zls"
  ];

  getFormatterCommand =
    formatter: if formatter.command != null then formatter.command else lib.getExe formatter.package;

  getLangServers = langName: lib.attrNames (langCfg.languages.${langName}.servers or { });

  getLangFormatter = langName: langCfg.languages.${langName}.formatter or null;

  getLangDebugger = langName: langCfg.languages.${langName}.debugger or null;

  # Get the command for a language server with proper fallbacks
  getServerCommand =
    name: server:
    if server.command != null then
      server.command
    else if lib.elem name builtinServers then
      name
    else
      null;

  # Check if a server config is valid (has at least a command or config)
  isValidServerConfig =
    name: server:
    let
      cmd = getServerCommand name server;
    in
    cmd != null || server.config != { };
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
        theme = "sonokai";

        editor = {
          completion-replace = true;
          lsp = {
            display-progress-messages = false;
            goto-reference-include-declaration = false;
            snippets = false;
          };
          trim-final-newlines = true;
          trim-trailing-whitespace = true;
          popup-border = "all";
          line-number = "relative";
          # gutters = [
          #   "diff"
          #   "diagnostics"
          #   "line-numbers"
          #   "spacer"
          # ];
          auto-format = true;

          auto-save = {
            enable = true;
            focus-lost = true;
            after-delay = {
              enable = true;
              timeout = 200;
            };
          };
          bufferline = "multiple";
          indent-guides = {
            render = true;
          };
          end-of-line-diagnostics = "hint";
          inline-diagnostics = {
            cursor-line = "disable";
            other-lines = "disable";
          };

          soft-wrap = {
            enable = true;
          };

          shell = [
            "nu"
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
              i = {
                c = ":toggle inline-diagnostics.cursor-line hint disable";
                e = ":toggle end-of-line-diagnostics warning disable";
                o = ":toggle inline-diagnostics.other-lines error disable";

              };
              t = {
                "1" = ":theme ${config.programs.darkMode.apps.helix.dark}";
                "2" = ":theme ${config.programs.darkMode.apps.helix.light}";

              };

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
                debugger = getLangDebugger langName;
              in
              {
                name = helixLangName;
                auto-format = true;
                language-servers = getLangServers langName;
              }
              // lib.optionalAttrs (langConfig.scope != null) { inherit (langConfig) scope; }
              // {
                # Use fileTypes if specified, otherwise derive from extensions
                file-types = if langConfig.fileTypes != [ ] then langConfig.fileTypes else langConfig.extensions;
              }
              // lib.optionalAttrs (langConfig.roots != [ ]) { inherit (langConfig) roots; }
              // lib.optionalAttrs (formatter != null) {
                formatter.command = getFormatterCommand formatter;
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

            # Filter out servers that would generate empty/invalid configs
            validServers = lib.filterAttrs (name: server: isValidServerConfig name server) enabledServers;
          in
          lib.mapAttrs' mkServerConfig validServers;
      };
    };

    programs.languages.enable = true;
  };
}
