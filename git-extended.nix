# Extended Git configuration module
# Provides additional configuration options beyond standard home-manager programs.git
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.git-extended;
in
{
  options.programs.git-extended = {
    enable = lib.mkEnableOption "extended git configuration";

    userName = lib.mkOption {
      type = lib.types.str;
      description = "Git user name";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      description = "Git user email";
    };

    signing = lib.mkOption {
      type = lib.types.submodule {
        options = {
          signByDefault = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to sign commits by default";
          };
          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "GPG key ID for signing";
          };
        };
      };
      default = { };
      description = "Git signing configuration";
    };

    enableDelta = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable delta for git diff";
    };

    enableRepoHelpers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable repository management helpers (rerere, autosquash, etc.)";
    };

    enableGitHubIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable GitHub CLI integration for credentials";
    };

    enableDiffTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure external diff and merge tools (meld)";
    };

    defaultEditor = lib.mkOption {
      type = lib.types.package;
      default = pkgs.helix;
      defaultText = lib.literalExpression "pkgs.helix";
      description = "Default editor for git commits";
    };

    additionalIgnores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional patterns to add to global gitignore";
      example = [
        "*.log"
        "temp/"
      ];
    };

    additionalAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional git aliases";
      example = {
        pushf = "push --force-with-lease";
        wip = "commit -m 'WIP'";
      };
    };

    customConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional git configuration options";
    };

    enableSensibleDefaults = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable sensible git defaults for modern workflows";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      package = pkgs.git;

      inherit (cfg) userName;
      inherit (cfg) userEmail;

      signing = lib.mkIf (cfg.signing.key != null) {
        inherit (cfg.signing) signByDefault;
        inherit (cfg.signing) key;
      };

      delta = lib.mkIf cfg.enableDelta {
        enable = true;
        options = {
          navigate = true;
          hyperlinks = true;
          line-numbers = true;
        };
      };

      ignores = [
        "CLAUDE.local.md"
        "TODO.md"
        "AGENTS.md"
        ".claude/"
        ".claude.md"

        ".idea/"
        "*.swp"
        "*.swo"
        "*~"

        ".DS_Store"
        ".DS_Store?"
        "._*"
        ".Spotlight-V100"
        ".Trashes"
        "ehthumbs.db"
        "Thumbs.db"

        ".direnv/"
        "result"
        "result-*"
      ]
      ++ cfg.additionalIgnores;

      extraConfig = lib.mkMerge [
        {
          branch.sort = "-committerdate";
          tag.sort = "version:refname";
          init.defaultBranch = "main";

          push = {
            default = "simple";
            autoSetupRemote = true;
            followTags = true;
          };

          fetch = {
            prune = true;
            pruneTags = true;
            all = true;
          };

          help.autocorrect = "prompt";
          commit.verbose = true;
          pull.rebase = true;

          core = {
            editor = "${cfg.defaultEditor}/bin/${cfg.defaultEditor.pname or cfg.defaultEditor.name}";
          };

          diff = {
            algorithm = "histogram";
            colorMoved = "default";
            mnemonicPrefix = true;
            renames = true;
          }
          // lib.optionalAttrs cfg.enableDiffTools {
            tool = "meld";
          };

          alias = {
            st = "status -sb";
            co = "checkout";
            cob = "checkout -b";
            br = "branch";
            ci = "commit";
            a = "add";
            d = "diff";
            dc = "diff --cached";
            ds = "diff --stat";

            ca = "commit -a --verbose";
            cm = "commit -m";
            cam = "commit -a -m";
            amend = "commit --amend";

            l = "log --pretty=format:'%C(yellow)%h %ad%C(red)%d %C(reset)%s%C(blue) [%cn]' --decorate --date=short";
            lg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
            last = "log -1 HEAD";

            undo = "reset HEAD~1 --mixed";
            unstage = "reset HEAD --";

            aliases = "config --get-regexp alias";
            save = "!git add -A && git commit -m 'SAVEPOINT'";
          }
          // lib.optionalAttrs cfg.enableDiffTools {
            meld = "!git difftool -t meld --dir-diff";
          }
          // cfg.additionalAliases;
        }

        (lib.optionalAttrs cfg.enableRepoHelpers {
          rerere = {
            enabled = true;
            autoupdate = true;
          };

          rebase = {
            autoSquash = true;
            autoStash = true;
            updateRefs = true;
          };

          merge = {
            conflictstyle = "zdiff3";
          }
          // lib.optionalAttrs cfg.enableDiffTools {
            tool = "meld";
          };
        })

        (lib.optionalAttrs cfg.enableDiffTools {
          difftool = {
            prompt = false;
            meld.cmd = ''${pkgs.meld}/bin/meld "$LOCAL" "$REMOTE"'';
          };

          mergetool.meld.cmd = ''${pkgs.meld}/bin/meld "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"'';
        })

        (lib.optionalAttrs cfg.enableGitHubIntegration {
          credential = {
            "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
            "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
            helper = "store";
          };
        })

        cfg.customConfig
      ];
    };
  };
}
