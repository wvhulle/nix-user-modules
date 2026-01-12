{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.languages;

  # Common server configurations
  typosServer = {
    package = pkgs.typos-lsp;
    name = "typos_lsp";
  };

  astGrepServer = {
    package = pkgs.ast-grep;
    args = [ "lsp" ];
    name = "ast_grep";
  };

  # Import all language definitions
  defaultLanguages = {
    yaml = {
      servers.yaml-language-server = {
        package = pkgs.yaml-language-server;
        name = "yamlls";
      };
    };
    rust = import ./rust.nix {
      inherit
        lib
        pkgs
        config
        typosServer
        astGrepServer
        ;
    };
    cpp = import ./cpp.nix { inherit pkgs astGrepServer; };
    javascript = import ./javascript.nix { inherit pkgs astGrepServer; };
    nix = import ./nix.nix {
      inherit
        lib
        pkgs
        typosServer
        astGrepServer
        ;
    };
    nushell = import ./nushell.nix { inherit pkgs typosServer; };
    typst = import ./typst.nix { inherit pkgs typosServer astGrepServer; };
    markdown = import ./markdown.nix { inherit pkgs typosServer; };
    lean = import ./lean.nix { inherit pkgs; };
    sh = import ./sh.nix { };
    nickel = import ./nickel.nix { inherit pkgs; };
    python = import ./python.nix { inherit pkgs astGrepServer; };
    zig = import ./zig.nix { inherit pkgs; };
    typescript = import ./typescript.nix { };
    agda.enable = false;
    coq.enable = false;
    haskell.enable = false;
  };

  # Type definitions
  toolType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        package = lib.mkOption {
          type = lib.types.package;
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        command = lib.mkOption {
          type = lib.types.str;
          default = lib.getExe config.package;
        };
      };
    }
  );

  serverType = lib.types.submodule (
    { config, name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
        };
        command = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        config = lib.mkOption {
          type = lib.types.attrs;
          default = { };
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = lib.replaceStrings [ "-" ] [ "_" ] name;
          description = "Canonical server name for editors (defaults to attribute name with dashes replaced by underscores)";
        };
      };
      config.command = lib.mkIf (config.package != null) (lib.mkDefault (lib.getExe config.package));
    }
  );

  debuggerType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
        };
        name = lib.mkOption {
          type = lib.types.str;
        };
        transport = lib.mkOption {
          type = lib.types.enum [
            "stdio"
            "tcp"
          ];
          default = "stdio";
        };
        command = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        templates = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                request = lib.mkOption {
                  type = lib.types.enum [
                    "launch"
                    "attach"
                  ];
                };
                completion = lib.mkOption {
                  type = lib.types.listOf lib.types.anything;
                  default = [ ];
                };
                args = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                };
              };
            }
          );
          default = [ ];
        };
      };
      config.command = lib.mkIf (config.package != null) (lib.mkDefault (lib.getExe config.package));
    }
  );

  terminalCommandType = lib.types.submodule {
    options = {
      autoApprove = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      exactCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      regexPatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  commandType = lib.types.submodule {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        description = "Brief command description (shown in help/autocomplete)";
      };
      prompt = lib.mkOption {
        type = lib.types.str;
        description = "The prompt content/instructions";
      };
      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tools allowed for Claude Code (e.g., Bash(cargo:*), Read(//))";
      };
      argumentHint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hint for expected arguments (e.g., <file> [pattern])";
      };
    };
  };

  languageType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      scope = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "File extensions for this language (used by Helix file-types and AI agent matching)";
      };
      fileTypes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional file type patterns for Helix (globs, shebang patterns)";
      };
      roots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      instructions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "AI agent instructions for this language";
      };
      commands = lib.mkOption {
        type = lib.types.attrsOf commandType;
        default = { };
        description = "Language-specific commands/prompts shared between Claude Code and VSCode Copilot";
      };
      terminalCommands = lib.mkOption {
        type = lib.types.attrsOf terminalCommandType;
        default = { };
        description = "Language-specific terminal command auto-approval settings";
      };
      formatter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
      };
      linter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
      };
      compiler = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
      };
      debugger = lib.mkOption {
        type = lib.types.nullOr debuggerType;
        default = null;
      };
      servers = lib.mkOption {
        type = lib.types.attrsOf serverType;
        default = { };
      };
      additionalPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      additionalPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
    };
  };

  enabledLanguages = lib.attrValues (lib.filterAttrs (_: l: l.enable) cfg.languages);

  # Helper to collect enabled tools from all languages
  collectTools = field: predicate: lib.filter predicate (map (lang: lang.${field}) enabledLanguages);

  allFormatters = collectTools "formatter" (f: f != null && f.enable);
  allLinters = collectTools "linter" (l: l != null && l.enable);
  allCompilers = collectTools "compiler" (c: c != null && c.enable);
  allDebuggers = collectTools "debugger" (d: d != null && d.enable);
  allAdditionalPaths = lib.concatMap (lang: lang.additionalPaths) enabledLanguages;
  allAdditionalPackages = lib.concatMap (lang: lang.additionalPackages) enabledLanguages;
  allLSPServers = lib.concatMap (
    lang:
    lib.pipe lang.servers [
      (lib.filterAttrs (_: s: s.enable && s.package != null))
      lib.attrValues
      (map (s: s.package))
    ]
  ) enabledLanguages;
in
{
  options.programs.languages = {
    enable = lib.mkEnableOption "unified language toolchain configuration";

    languages = lib.mkOption {
      type = lib.types.attrsOf languageType;
      default = defaultLanguages;
      description = "Language toolchain configurations";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.topiary = {
      enable = true;
      languages.nu = {
        extensions = [ "nu" ];
        queryFile = "${pkgs.topiary-nushell-queries}/languages/nu.scm";
        grammar.source.git = {
          git = "https://github.com/nushell/tree-sitter-nu.git";
          rev = "18b7f951e0c511f854685dfcc9f6a34981101dd6";
        };
      };
    };

    home = {
      sessionPath = allAdditionalPaths;
      packages =
        (map (f: f.package) allFormatters)
        ++ (map (l: l.package) allLinters)
        ++ (map (c: c.package) allCompilers)
        ++ (map (d: d.package) allDebuggers)
        ++ allAdditionalPackages
        ++ allLSPServers;
    };
  };
}
