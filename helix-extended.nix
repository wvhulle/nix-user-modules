{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;
  enabledLanguages = lib.filterAttrs (_: l: l.enable) langCfg.languages;

  tomlFormat = pkgs.formats.toml { };

  helixSettings = {
    theme = "papercolor-dark";

    editor = {
      completion-replace = true;
      lsp = {
        display-progress-messages = true;
        display-inlay-hints = true;
        goto-reference-include-declaration = false;
        snippets = false;
      };
      trim-final-newlines = true;
      trim-trailing-whitespace = true;
      popup-border = "all";
      line-number = "relative";
      rulers = [ ];
      auto-format = true;

      auto-save = {
        enable = true;
        focus-lost = true;
        after-delay = {
          enable = true;
          timeout = 500;
        };
      };
      bufferline = "multiple";
      indent-guides = {
        render = true;
      };
      end-of-line-diagnostics = "disable";
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
        "C-l" = [
          ":write-all"
          ":run-shell-command zellij run --in-place -c -- lazygit -p %sh{dirname %{buffer_name}}"
          ":redraw"
          ":reload-all"
        ];
        space = {
          i = {
            c = ":toggle inline-diagnostics.cursor-line hint disable";
            e = ":toggle end-of-line-diagnostics warning disable";
            o = ":toggle inline-diagnostics.other-lines error disable";
          };
          t = {
            d = ":theme papercolor-dark";
            l = ":theme papercolor-light";
          };

          B = ''
            :echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}
          '';
          N = ":run-shell-command ${./helix-copy-filename.nu} %{buffer_name}";
          L = ":echo %sh{${./helix-repo-link.nu} %{buffer_name} %{cursor_line}}";
        };
      };
    };
  };

  darkConfig = tomlFormat.generate "config-dark.toml" (
    helixSettings // { theme = "papercolor-dark"; }
  );
  lightConfig = tomlFormat.generate "config-light.toml" (
    helixSettings // { theme = "papercolor-light"; }
  );
in
{
  options.programs.helix-extended = {
    enable = lib.mkEnableOption "extended helix configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = true;

      languages =
        let
          cleanup = lib.filterAttrs (_: v: v != null && v != [ ] && v != { });

          toHelixLanguage =
            name: lang:
            {
              inherit name;
              auto-format = true;
              language-servers = lib.attrNames (lang.servers or { });
              file-types = if lang.fileTypes != [ ] then lang.fileTypes else lang.extensions;
            }
            // cleanup {
              inherit (lang) scope roots;
              auto-pairs = lang.autoPairs;
              grammar = if lang.grammar != null then lang.grammar.name else null;
              formatter =
                if lang.formatter != null then
                  {
                    inherit (lang.formatter) command args;
                  }
                else
                  null;
              debugger =
                if lang.debugger != null && lang.debugger.enable then
                  cleanup {
                    inherit (lang.debugger)
                      name
                      transport
                      command
                      templates
                      args
                      ;
                  }
                else
                  null;
            };

          toHelixServer = _: server: cleanup { inherit (server) command args config; };

          toHelixGrammar =
            _: lang:
            let
              g = lang.grammar;
            in
            {
              inherit (g) name;
            };

          allGrammarsLangs = lib.filterAttrs (_: l: l.grammar != null) enabledLanguages;
        in
        {
          language = lib.sortOn (l: l.name) (lib.mapAttrsToList toHelixLanguage enabledLanguages);

          language-server = lib.mapAttrs toHelixServer langCfg.servers;

          grammar = lib.mapAttrsToList toHelixGrammar allGrammarsLangs;
        };
    };

    # Place pre-built grammars and query files into the Helix runtime
    xdg.configFile =
      let
        prebuiltGrammars = lib.filterAttrs (
          _: l: l.grammar != null && l.grammar.package != null
        ) enabledLanguages;

        languagesWithQueries = lib.filterAttrs (
          _: l: l.grammar != null && l.queries != { }
        ) enabledLanguages;

        # Pre-built grammar .so — force to overwrite files left by `hx --grammar build`
        grammarFiles = lib.mapAttrs' (
          _: lang:
          let
            g = lang.grammar;
          in
          lib.nameValuePair "helix/runtime/grammars/${g.name}.so" {
            source = "${g.package}/${g.name}.so";
            force = true;
          }
        ) prebuiltGrammars;

        queryFiles = lib.concatMapAttrs (
          _: lang:
          let
            g = lang.grammar;
          in
          lib.mapAttrs' (
            queryName: queryPath:
            lib.nameValuePair "helix/runtime/queries/${g.name}/${queryName}.scm" {
              source = queryPath;
            }
          ) lang.queries
        ) languagesWithQueries;
      in
      grammarFiles
      // queryFiles
      // {
        "helix/config-dark.toml".source = darkConfig;
        "helix/config-light.toml".source = lightConfig;
      };

    home.activation.helixConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mode=$(${pkgs.darkman}/bin/darkman get 2>/dev/null || echo "dark")
      if [ "$mode" = "light" ]; then
        install -m 644 ${lightConfig} "${config.xdg.configHome}/helix/config.toml"
      else
        install -m 644 ${darkConfig} "${config.xdg.configHome}/helix/config.toml"
      fi
    '';

    assertions =
      let
        prebuiltGrammars = lib.filterAttrs (
          _: l: l.grammar != null && l.grammar.package != null
        ) enabledLanguages;
      in
      lib.mapAttrsToList (
        name: lang:
        let
          g = lang.grammar;
        in
        {
          assertion = builtins.pathExists (g.package + "/${g.name}.so");
          message = "Helix grammar package for language '${name}' does not contain '${g.name}.so' at ${g.package}/. Check that grammar.name matches the .so filename in the package output.";
        }
      ) prebuiltGrammars;

    programs.languages.enable = true;
  };
}
