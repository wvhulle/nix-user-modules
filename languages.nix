{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.languages;
  lspCfg = config.programs.lsp;

  topiary-nu-module = pkgs.fetchFromGitHub {
    owner = "blindfs";
    repo = "topiary-nushell";
    rev = "fd78be393af5a64e56b493f52e4a9ad1482c07f4";
    sha256 = "sha256-5gmLFnbHbQHnE+s1uAhFkUrhEvUWB/hg3/8HSYC9L14=";
  };

  toolType = lib.types.submodule {
    options = {
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
  };

  serverType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this language server";
      };
      package = lib.mkOption {
        type = lib.types.package;
        description = "Package providing the language server";
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the language server (defaults to package binary)";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments to pass to the language server";
      };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Configuration for the language server";
      };
    };
  };

  formatterType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this formatter";
      };
      package = lib.mkOption {
        type = lib.types.package;
        description = "Package providing the formatter";
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Command to run the formatter (defaults to package binary)";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments to pass to the formatter";
      };
    };
  };

  defaultServers = {
    nil = {
      package = pkgs.nil;
    };
    rust-analyzer = {
      package = pkgs.rust-analyzer;
      config = {
        cargo = {
          allFeatures = true;
          allTargets = false;
        };
        check.command = "clippy";
      };
    };
    tinymist = {
      package = pkgs.tinymist;
      config.preview.background = {
        enabled = true;
        args = [
          "--data-plane-host=127.0.0.1:23635"
          "--open"
        ];
      };
    };
    typos-lsp = {
      package = pkgs.typos-lsp;
    };
    nu-lint = {
      package = pkgs.nu-lint;
      args = [ "--lsp" ];
    };
  };

  defaultFormatters = {
    dprint = {
      package = pkgs.dprint;
      args = [
        "fmt"
        "--stdin"
      ];
    };
    nixfmt = {
      package = pkgs.nixfmt-rfc-style;
    };
    topiary = {
      package = pkgs.topiary;
      args = [
        "format"
        "--language"
      ];
    };
    typstyle = {
      package = pkgs.typstyle;
    };
  };

  enabledServers = lib.filterAttrs (_: s: s.enable) lspCfg.servers;
  enabledFormatters = lib.filterAttrs (_: f: f.enable) lspCfg.formatters;

  languageType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this language";
      };

      formatter = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of formatter from programs.lsp.formatters to use for this language";
      };

      linter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Linter for this language";
      };

      lsp = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of language server names from programs.lsp.servers to use for this language";
      };

      compiler = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Compiler for this language";
      };

      additionalPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths to add to PATH for this language (e.g., ~/.cargo/bin for Rust)";
      };
    };
  };

  defaultLanguages = {
    nushell = {
      formatter = "topiary";
      linter = {
        package = pkgs.nu-lint;
      };
      lsp = [
        "nu-lint"
        "typos-lsp"
      ];
    };
    nix = {
      formatter = "nixfmt";
      lsp = [
        "nil"
        "typos-lsp"
      ];
    };
    rust = {
      lsp = [
        "rust-analyzer"
        "typos-lsp"
      ];
      additionalPaths = [ "${config.home.homeDirectory}/.cargo/bin" ];
    };
    typst = {
      formatter = "typstyle";
      lsp = [
        "tinymist"
        "typos-lsp"
      ];
      compiler = {
        package = pkgs.typst;
      };
    };
    markdown = {
      formatter = "dprint";
      lsp = [ "typos-lsp" ];
    };
  };
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

  options.programs.lsp = {
    enable = lib.mkEnableOption "language server protocol configurations";

    servers = lib.mkOption {
      type = lib.types.attrsOf serverType;
      default = defaultServers;
      description = "Language server configurations";
    };

    formatters = lib.mkOption {
      type = lib.types.attrsOf formatterType;
      default = defaultFormatters;
      description = "Formatter configurations";
    };
  };

  config =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable) cfg.languages;
      allAdditionalPaths = lib.flatten (
        lib.mapAttrsToList (_name: langCfg: langCfg.additionalPaths) enabledLanguages
      );
    in
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        programs = {
          lsp.enable = true;

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

          # Add language-specific paths to PATH for nushell specifically
          nushell-extended.additionalPaths = allAdditionalPaths;
        };
        # Add language-specific paths to PATH for non-nushell shells and desktop sessions
        home.sessionPath = allAdditionalPaths;

      })

      (lib.mkIf lspCfg.enable {
        home.packages =
          (lib.mapAttrsToList (_: s: s.package) enabledServers)
          ++ (lib.mapAttrsToList (_: f: f.package) enabledFormatters);
      })
    ];
}
