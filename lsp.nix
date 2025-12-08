{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.lsp;

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
      package = pkgs.nixfmt-classic;
    };
    topiary = {
      package = pkgs.topiary;
      args = [
        "format"
        "--language"
      ];
    };
  };

  enabledServers = lib.filterAttrs (_: s: s.enable) cfg.servers;
  enabledFormatters = lib.filterAttrs (_: f: f.enable) cfg.formatters;
in
{
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

  config = lib.mkIf cfg.enable {
    home.packages =
      (lib.mapAttrsToList (_: s: s.package) enabledServers)
      ++ (lib.mapAttrsToList (_: f: f.package) enabledFormatters);
  };
}
