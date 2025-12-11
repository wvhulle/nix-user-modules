{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.languages;

  topiary-nu-module = pkgs.fetchFromGitHub {
    owner = "blindfs";
    repo = "topiary-nushell";
    rev = "fd78be393af5a64e56b493f52e4a9ad1482c07f4";
    sha256 = "sha256-5gmLFnbHbQHnE+s1uAhFkUrhEvUWB/hg3/8HSYC9L14=";
  };

  toolOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable this tool";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package providing the tool";
    };
    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments to pass to the tool";
    };
  };

  toolType = lib.types.submodule { options = toolOptions; };

  serverType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this tool";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Package providing the tool (null if externally managed)";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional arguments to pass to the tool";
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the language server (defaults to package binary)";
      };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Configuration for the language server";
      };
    };
  };

  formatterType = lib.types.submodule {
    options = toolOptions // {
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the formatter (defaults to package binary)";
      };
    };
  };

  typosServer = {
    package = pkgs.typos-lsp;
  };

  languageType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this language";
      };

      formatter = lib.mkOption {
        type = lib.types.nullOr formatterType;
        default = null;
        description = "Formatter configuration for this language";
      };

      linter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Linter for this language";
      };

      servers = lib.mkOption {
        type = lib.types.attrsOf serverType;
        default = { };
        description = "Language servers for this language";
      };

      compiler = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Compiler for this language";
      };

      additionalPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths to add to PATH for this language";
      };
    };
  };

  defaultLanguages = {
    nushell = {
      formatter = {
        package = pkgs.topiary;
        args = [
          "format"
          "--language"
        ];
      };
      linter.package = pkgs.nu-lint;
      servers = {
        nu-lint = {
          package = pkgs.nu-lint;
          args = [ "--lsp" ];
        };
        typos-lsp = typosServer;
      };
    };
    nix = {
      formatter.package = pkgs.nixfmt-rfc-style;
      servers = {
        nil.package = pkgs.nil;
        typos-lsp = typosServer;
      };
    };
    rust = {
      servers = {
        rust-analyzer = {
          config = {
            cachePriming.enable = true;
            imports.preferNoStd = true;
            lens.references.method.enable = true;
            completion.postfix.enable = false;
            diagnostics.experimental.enable = true;
            cargo = {
              allFeatures = true;
              allTargets = false;
            };
            check.command = "clippy";
          };
        };
        typos-lsp = typosServer;
      };
      additionalPaths = [ "${config.home.homeDirectory}/.cargo/bin" ];
    };
    typst = {
      formatter.package = pkgs.typstyle;
      servers = {
        tinymist = {
          command = "tinymist";
          package = pkgs.tinymist;
          config.preview.background = {
            exportPdf = "onType";
            enabled = true;
            args = [
              "--data-plane-host=127.0.0.1:23635"
              "--open"
              "--invert-colors=auto"
            ];
          };
        };
        typos-lsp = typosServer;
      };
      compiler.package = pkgs.typst;
    };
    markdown = {
      formatter = {
        package = pkgs.dprint;
        args = [
          "fmt"
          "--stdin"
        ];
      };
      servers.typos-lsp = typosServer;
    };
  };

  enabledLanguages = lib.filterAttrs (_: l: l.enable) cfg.languages;

  allServers = lib.filter (s: s.package != null) (
    lib.flatten (
      lib.mapAttrsToList (
        _: lang: lib.attrValues (lib.filterAttrs (_: s: s.enable) lang.servers)
      ) enabledLanguages
    )
  );

  allFormatters = lib.filter (f: f != null && f.enable) (
    lib.mapAttrsToList (_: lang: lang.formatter) enabledLanguages
  );

  allLinters = lib.filter (l: l != null && l.enable) (
    lib.mapAttrsToList (_: lang: lang.linter) enabledLanguages
  );

  allCompilers = lib.filter (c: c != null && c.enable) (
    lib.mapAttrsToList (_: lang: lang.compiler) enabledLanguages
  );

  allAdditionalPaths = lib.flatten (
    lib.mapAttrsToList (_: lang: lang.additionalPaths) enabledLanguages
  );
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
    programs = {
      topiary = {
        enable = true;
        languages.nu = {
          extensions = [ "nu" ];
          queryFile = "${topiary-nu-module}/languages/nu.scm";
          grammar.source.git = {
            git = "https://github.com/nushell/tree-sitter-nu.git";
            rev = "18b7f951e0c511f854685dfcc9f6a34981101dd6";
          };
        };
      };

      nushell-extended.additionalPaths = allAdditionalPaths;
    };

    home = {
      sessionPath = allAdditionalPaths;

      packages =
        (map (s: s.package) allServers)
        ++ (map (f: f.package) allFormatters)
        ++ (map (l: l.package) allLinters)
        ++ (map (c: c.package) allCompilers);
    };
  };
}
