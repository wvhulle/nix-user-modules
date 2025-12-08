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

  languageType = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this language toolchain";

      formatter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Code formatter for this language";
      };

      linter = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Linter for this language";
      };

      lsp = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Language server for this language";
      };

      compiler = lib.mkOption {
        type = lib.types.nullOr toolType;
        default = null;
        description = "Compiler for this language";
      };
    };
  };
in
{
  options.programs.languages = {
    enable = lib.mkEnableOption "unified language toolchain configuration";

    nushell = lib.mkOption {
      type = languageType;
      default = {
        formatter = {
          package = pkgs.topiary;
          enable = true;
        };
        linter = {
          package = pkgs.nu-lint;
          enable = true;
        };
        lsp = {
          package = pkgs.nu-lint;
          enable = true;
          args = [ "--lsp" ];
        };
      };
      description = "Nushell language toolchain configuration";
    };

    nix = lib.mkOption {
      type = languageType;
      default = {
        formatter = {
          package = pkgs.nixfmt-rfc-style;
          enable = true;
        };
        lsp = {
          package = pkgs.nil;
          enable = true;
        };
      };
      description = "Nix language toolchain configuration";
    };

    rust = lib.mkOption {
      type = languageType;
      default = {
        lsp = {
          package = pkgs.rust-analyzer;
          enable = true;
        };
      };
      description = "Rust language toolchain configuration";
    };

    typst = lib.mkOption {
      type = languageType;
      default = {
        formatter = {
          package = pkgs.typstyle;
          enable = true;
        };
        lsp = {
          package = pkgs.tinymist;
          enable = true;
        };
        compiler = {
          package = pkgs.typst;
          enable = true;
        };
      };
      description = "Typst language toolchain configuration";
    };

    markdown = lib.mkOption {
      type = languageType;
      default = {
        formatter = {
          package = pkgs.dprint;
          enable = true;
          args = [
            "fmt"
            "--stdin"
          ];
        };
      };
      description = "Markdown formatting configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lsp.enable = true;

    programs.topiary = lib.mkIf cfg.nushell.enable {
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
  };
}
