# Typos LSP Module
#
# Typos is a semantic-aware spell checker that uses tree-sitter for understanding
# code structure. It focuses on common misspellings and provides low false positives
# by distinguishing between code constructs and natural language text.
#
# ## Features
# - Tree-sitter based semantic awareness
# - LSP integration for real-time checking in editors
# - Low false positives - only flags known common misspellings
# - Language-aware spell checking in comments and documentation
# - Fast Rust-based performance
#
# ## Configuration
# - Global config: ~/.typos.toml (managed by this module)
# - Project overrides: typos.toml, _typos.toml, or .typos.toml in workspace
#
# ## Editor Integration
# - VSCode: typos-vscode extension (configured separately)
# - Neovim: Configure LSP client for typos-lsp
# - Other LSP-compatible editors
#
# ## Usage
# - Command line: `typos` to check files
# - LSP server: Automatic integration in supported editors
# - Enforce backtick convention: Technical terms in prose should use `backticks`
#
# ## Reference
# Based on typos 1.32.0 configuration reference:
# https://github.com/crate-ci/typos/blob/master/docs/reference.md

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.typos;

  tomlFormat = pkgs.formats.toml { };

  typosConfig = {
    files.extend-exclude = cfg.excludePatterns;

    default = {
      inherit (cfg) locale;
      unicode = cfg.enableUnicode;
      check-filename = cfg.checkFilename;
      check-file = cfg.checkFile;
    }
    // lib.optionalAttrs (cfg.ignoreRegexes != [ ]) { extend-ignore-re = cfg.ignoreRegexes; }
    // lib.optionalAttrs (cfg.ignoreIdentifiersRe != [ ]) {
      extend-ignore-identifiers-re = cfg.ignoreIdentifiersRe;
    }
    // lib.optionalAttrs (cfg.ignoreWordsRe != [ ]) {
      extend-ignore-words-re = cfg.ignoreWordsRe;
    }
    // lib.optionalAttrs (cfg.extendWords != { }) { extend-words = cfg.extendWords; }
    // lib.optionalAttrs (cfg.extendIdentifiers != { }) {
      extend-identifiers = cfg.extendIdentifiers;
    };
  }
  // lib.optionalAttrs (cfg.fileTypes != { }) (
    lib.mapAttrs' (name: globs: lib.nameValuePair "type.${name}" { extend-glob = globs; }) cfg.fileTypes
  );

  # Generate TOML file
  typosConfigFile = tomlFormat.generate "typos.toml" typosConfig;
in
{
  options = {
    programs.typos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable typos spell checker with LSP support";
      };

      excludePatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "*.lock"
          "target/**"
          "result/**"
          ".direnv/**"
          ".lake/**"
          "build/**"
          "_target/**"
          "*.olean"
        ];
        description = "File patterns to exclude from spell checking (gitignore syntax)";
      };

      locale = lib.mkOption {
        type = lib.types.enum [
          "en"
          "en-us"
          "en-gb"
          "en-ca"
          "en-au"
        ];
        default = "en";
        description = ''
          English dialect to correct to.
          If set to "en", words will be corrected to the closest spelling, regardless of dialect.
        '';
      };

      enableUnicode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow unicode characters in identifiers (not just ASCII)";
      };

      checkFilename = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Verify spelling in file names (directory names are not checked)";
      };

      checkFile = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Verify spelling in file contents";
      };

      ignoreRegexes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "(?m)^```[\\s\\S]*?^```" # Code blocks in markdown
          "`[^`]+`" # Inline code
          "\\$\\$[\\s\\S]*?\\$\\$" # LaTeX math blocks
          "\\$[^$]+\\$" # Inline LaTeX math
          "https?://[^\\s]+" # URLs
          "#[0-9]+" # Issue numbers
          "@[a-zA-Z0-9_-]+" # GitHub mentions
        ];
        description = "Custom uncorrectable sections (e.g. markdown code fences, URLs, etc.)";
      };

      ignoreIdentifiersRe = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          ".*Color.*" # VSCode settings use American spelling
          ".*Center.*" # VSCode settings use American spelling
          "rust-analyzer.*" # Tool name shouldn't be changed
        ];
        description = "Pattern-match always-valid identifiers (code symbols)";
      };

      ignoreWordsRe = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          ".*[Aa]nalyzer.*" # rust-analyzer, analyzer tools
          ".*[Aa]uthorized.*" # SSH authorizedKeys, etc.
          "[a-z]+Inputs" # buildInputs, nativeBuildInputs, etc.
          "[a-z]+Phase" # buildPhase, installPhase, etc.
          "std[A-Z].*" # stdenv and similar
          "^(als|simp|rfl|rw|tac)$" # Specific short technical abbreviations
        ];
        description = "Pattern-match always-valid words (note: you must handle case insensitivity yourself)";
      };

      extendWords = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Corrections for words (natural language text).
          When correction equals the key, the word is always valid.
          When correction is blank, the word is never valid.
        '';
        example = lib.literalExpression ''
          {
            wvhulle = "wvhulle";  # Always valid
            badword = "";         # Never valid
          }
        '';
      };

      extendIdentifiers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Corrections for identifiers (code symbols like variable names).
          When correction equals the key, the identifier is always valid.
          When correction is blank, the identifier is never valid.
        '';
        example = lib.literalExpression ''
          {
            ERROR_CODE_TYPO = "ERROR_CODE";  # Correction
          }
        '';
      };

      fileTypes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = ''
          Define custom file type glob patterns.
          Use `typos --type-list` to see available type names.
        '';
        example = lib.literalExpression ''
          {
            nix = [ "*.nix" "flake.lock" ];
            docs = [ "*.md" "*.rst" ];
          }
        '';
      };

      additionalConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional raw TOML configuration to append to the generated file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install typos and typos-lsp
    home.packages = with pkgs; [
      typos
      typos-lsp
    ];

    home.file.".typos.toml" = lib.mkMerge [
      { source = typosConfigFile; }
      (lib.mkIf (cfg.additionalConfig != "") {
        text = builtins.readFile typosConfigFile + "\n" + cfg.additionalConfig;
      })
    ];
  };
}
