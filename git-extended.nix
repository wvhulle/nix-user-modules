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
      default = false;
      description = "Whether to enable delta for git diff";
    };

    enableDifftastic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable difftastic for git diff";
    };

    enableGitHubIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable GitHub CLI integration for credentials";
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

    enableMergiraf = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable mergiraf as the default merge strategy";
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

      difftastic = lib.mkIf cfg.enableDifftastic {
        enable = true;
        background = "dark";
        color = "auto";
        display = "side-by-side-show-both";
      };

      ignores = [
        "CLAUDE.local.md"
        "TODO.md"
        "AGENTS.md"
        ".claude/"
        ".claude.md"
        ".core.*"
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
            meld = "!git difftool -t meld --dir-diff";
          }
          // cfg.additionalAliases;

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
            tool = "meld";
          };
        }

        {
          difftool = {
            prompt = false;
            meld.cmd = ''${pkgs.meld}/bin/meld "$LOCAL" "$REMOTE"'';
          };

          mergetool.meld.cmd = ''${pkgs.meld}/bin/meld "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"'';
        }

        (lib.optionalAttrs cfg.enableGitHubIntegration {
          credential = {
            "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
            "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
            helper = "store";
          };
        })

        (lib.optionalAttrs cfg.enableMergiraf {
          merge.mergiraf = {
            name = "mergiraf";
            driver = "${pkgs.mergiraf}/bin/mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
          };
        })
      ];
    };

    # Install mergiraf package when enabled
    home.packages = lib.optional cfg.enableMergiraf pkgs.mergiraf;

    # Configure global gitattributes for mergiraf
    home.file.".config/git/attributes" = lib.mkIf cfg.enableMergiraf {
      text = ''
        # Use mergiraf for all files
        * merge=mergiraf
      '';
    };
  };
}
