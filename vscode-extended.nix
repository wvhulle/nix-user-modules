{
  lib,
  config,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.programs.vscode-extended;
  agentCfg = config.programs.agents;
  fontsCfg = config.programs.typography;

  capitalize = name: lib.strings.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;

  generateLanguagePattern =
    extensions:
    if builtins.length extensions == 0 then
      "**/*"
    else if builtins.length extensions == 1 then
      "**/*.${builtins.head extensions}"
    else
      "**/*.{${lib.concatStringsSep "," extensions}}";

  mkMarketplaceExt =
    {
      name,
      publisher,
      version,
      sha256,
    }:
    pkgs.vscode-utils.extensionFromVscodeMarketplace {
      inherit
        name
        publisher
        version
        sha256
        ;
    };

  mkMarketplaceExts = extensions: map mkMarketplaceExt extensions;
  mkFormatter = formatter: { "editor.defaultFormatter" = formatter; };

  defaultMarketplaceExtensions = mkMarketplaceExts [
    {
      name = "claude-code";
      publisher = "anthropic";
      version = "2.0.61";
      sha256 = "sha256-dZu2CIjRyvAhTRwOuQV2s0SoEUQko+dQfnQg6ECwLv4=";
    }
    {
      name = "vscode-open-in-github";
      publisher = "ziyasal";
      version = "1.3.6";
      sha256 = "uJGCCvg6fj2He1HtKXC2XQLXYp0vTl4hQgVU9o5Uz5Q=";
    }
    {
      name = "nix-ide";
      publisher = "jnoortheen";
      version = "0.5.0";
      sha256 = "sha256-jVuGQzMspbMojYq+af5fmuiaS3l3moG8L8Kyf40vots=";
    }
    {
      name = "vscode-websearchforcopilot";
      publisher = "ms-vscode";
      version = "0.1.2025120401";
      sha256 = "sha256-Hj3822qatDMhpQzoLyk3RPLA8AJ5pt0XzUcLNZHrKmc=";
    }
    {
      name = "gitignore";
      publisher = "codezombiech";
      version = "0.10.0";
      sha256 = "0mmnylc7fbf6239m9fvplk8msns8di0v4bgb7wf0ly21p0g9acjr";
    }
    {
      name = "nu-lint";
      publisher = "WillemVanhulle";
      version = "0.0.13";
      sha256 = "sha256-76KK85Jd34U9VG+0RKImoEblcr7z1vqje2LdhbdSs/g=";
    }
    # {
    #   name = "rustowl-vscode";
    #   publisher = "cordx56";
    #   version = "0.3.4";
    #   sha256 = "sha256-sM4CxQfdtDkZg5B7gxw66k7ZpIfHQFORIukHRpg0+S8=";
    # }
  ];

  defaultNixpkgsExtensions = with unstable.vscode-extensions; [
    haskell.haskell
    justusadam.language-haskell
    vadimcn.vscode-lldb
    mkhl.direnv
    christian-kohler.path-intellisense
    ecmel.vscode-html-css
    fabiospampinato.vscode-open-in-github
    file-icons.file-icons
    vscode-icons-team.vscode-icons
    pkief.material-icon-theme
    formulahendry.auto-rename-tag
    github.copilot
    github.copilot-chat
    github.github-vscode-theme
    haskell.haskell
    ms-python.python
    ms-python.vscode-pylance
    ms-vscode.cpptools
    ms-vscode.cmake-tools
    ms-vscode-remote.remote-ssh
    ms-vscode-remote.remote-ssh-edit
    ms-vsliveshare.vsliveshare
    tamasfe.even-better-toml
    thenuprojectcontributors.vscode-nushell-lang
    tomoki1207.pdf
    davidanson.vscode-markdownlint
    esbenp.prettier-vscode
    dbaeumer.vscode-eslint
    tekumara.typos-vscode
    mechatroner.rainbow-csv
    gruntfuggly.todo-tree
    timonwong.shellcheck
    myriad-dreamin.tinymist
  ];

  languageFormatters = {
    "[css]" = mkFormatter "vscode.css-language-features";
    "[html]" = mkFormatter "vscode.html-language-features";
    "[javascript]" = mkFormatter "vscode.typescript-language-features";
    "[json]" = mkFormatter "vscode.json-language-features";
    "[jsonc]" = mkFormatter "vscode.json-language-features";
    "[markdown]" = mkFormatter "DavidAnson.vscode-markdownlint";
    "[nix]" = mkFormatter "jnoortheen.nix-ide";
    "[nushell]" = mkFormatter "constneo.vscode-nushell-format" // {
      "editor.formatOnSave" = true;
    };
    "[rust]" = mkFormatter "rust-lang.rust-analyzer";
    "[scss]" = mkFormatter "vscode.css-language-features";
    "[python]" = mkFormatter "charliermarsh.ruff";
    "[c]" = {
      "editor.formatOnSave" = false;
    };
    "[cpp]" = {
      "editor.formatOnSave" = false;
    };
  };

  editorSettings = {
    "editor.cursorBlinking" = "smooth";
    "editor.cursorSmoothCaretAnimation" = "on";
    "editor.fontFamily" = fontsCfg.editorFontFamily;
    "editor.fontSize" = fontsCfg.sizes.editor;
    "editor.fontLigatures" = true;
    "editor.formatOnSave" = true;
    "editor.smoothScrolling" = true;
    "editor.wordWrap" = "on";
  };

  windowSettings = {
    "window.autoDetectColorScheme" = true;
    "window.titleBarStyle" = "native";
    "window.commandCenter" = false;
    "window.menuBarVisibility" = "toggle";
    "workbench.list.smoothScrolling" = true;
    "workbench.preferredDarkColorTheme" = "GitHub Dark Default";
    "workbench.preferredLightColorTheme" = "GitHub Light Default";
    "workbench.editor.enablePreview" = false;
    "workbench.editor.highlightModifiedTabs" = true;
    "workbench.iconTheme" = "vscode-icons";
    "workbench.layoutControl.enabled" = false;
    "workbench.navigationControl.enabled" = false;
  };

  terminalSettings = {
    "terminal.integrated.fontFamily" = fontsCfg.terminalFontFamily;
    "terminal.integrated.fontSize" = fontsCfg.sizes.terminal;
    "terminal.integrated.smoothScrolling" = true;
    "terminal.integrated.defaultProfile.linux" = "bash";
    "terminal.integrated.profiles.linux" = {
      "fish" = {
        "path" = "${pkgs.fish}/bin/fish";
        "icon" = "terminal-bash";
      };
      "nushell" = {
        "path" = "${pkgs.nushell}/bin/nu";
        "icon" = "terminal-powershell";
      };
      "bash" = {
        "path" = "${pkgs.bash}/bin/bash";
        "icon" = "terminal-bash";
      };
    };
  };

  gitSettings = {
    "git.autofetch" = true;
    "git.confirmSync" = false;
    "git.openRepositoryInParentFolders" = "never";
  };

  languageServerSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "${pkgs.nil}/bin/nil";
    "nix.serverSettings" = {
      "nil" = {
        "formatting" = {
          "command" = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ];
        };
        "diagnostics" = {
          "ignored" = [
            "unused_binding"
            "unused_with"
          ];
        };
      };
    };

    "rust-analyzer.check.command" = "clippy";
    "rust-analyzer.completion.fullFunctionSignatures.enable" = true;
    "rust-analyzer.completion.postfix.enable" = false;
    "rust-analyzer.completion.privateEditable.enable" = true;
    "rust-analyzer.diagnostics.enable" = false;
    "rust-analyzer.imports.preferNoStd" = true;
    "rust-analyzer.lens.references.method.enable" = true;

    "python.analysis.typeCheckingMode" = "strict";

  };

  extensionSettings = {
    "direnv.restart.automatic" = true;
    "nixEnvSelector.useFlakes" = true;
    "extensions.autoCheckUpdates" = false;
    "extensions.autoUpdate" = false;

    "errorLens.enabledDiagnosticLevels" = [
      "error"
      "hint"
      "info"
      "warning"
    ];
    "errorLens.messageEnabled" = true;

    "typos.path" = "${pkgs.typos-lsp}/bin/typos-lsp";
    "typos.diagnosticSeverity" = "Information";

    "markdown.extension.completion.enabled" = true;
    "markdown.extension.toc.orderedList" = true;
    "markdownlint.config" = {
      "extends" = null;
    };

    "evenBetterToml.formatter.reorderKeys" = true;
    "evenBetterToml.formatter.reorderArrays" = false;
    "evenBetterToml.formatter.reorderInlineTables" = true;
    "evenBetterToml.taplo.extraArgs" = [
      "--option"
      "reorder_keys=true"
      "--option"
      "reorder_arrays=true"
    ];

    "githubPullRequests.terminalLinksHandler" = "github";
    "githubPullRequests.pullBranch" = "never";

    "lean4.automaticallyBuildDependencies" = true;
  };

  generateLanguageInstructionFile =
    name: langCfg:
    let
      pattern = generateLanguagePattern langCfg.extensions;
      numberedInstructions = lib.imap0 (i: instr: "${toString (i + 1)}. ${instr}") langCfg.instructions;
      instructionsText = lib.concatStringsSep "\n" numberedInstructions;
    in
    pkgs.writeText "${name}-copilot-instructions.md" ''
      ---
      applyTo: "${pattern}"
      description: "${capitalize name} coding standards and best practices"
      ---

      ${instructionsText}
    '';

  generateBaseInstructionFile =
    let
      numberedInstructions = lib.imap0 (
        i: instr: "${toString (i + 1)}. ${instr}"
      ) agentCfg.baseInstructions;
      instructionsText = lib.concatStringsSep "\n" numberedInstructions;
    in
    pkgs.writeText "base.instructions.md" ''
      ---
      applyTo: "**"
      description: "General coding guidelines for all file types"
      ---

      ${instructionsText}
    '';

  copilotBaseInstructionsSettings = {
    "github.copilot.chat.codeGeneration.useInstructionFiles" = true;
  };

  copilotAutoApprovalSettings = {
    "chat.agent.enabled" = true;
    "chat.agent.maxRequests" = 100000;
    "github.copilot.chat.agent.runTasks" = true;
    "github.copilot.chat.agent.autoFix" = true;
    "github.copilot.nextEditSuggestions.enabled" = true;
    "chat.tools.autoApprove" = true;
    "chat.tools.global.autoApprove" = true;
    "chat.tools.edits.autoApprove" = {
      "**/*" = true;
      "**/.vscode/*.json" = false;
      "**/.env" = false;
      "**/configuration.nix" = false;
      "**/hardware-configuration.nix" = false;
    };

    "chat.tools.terminal.autoApprove" = agentCfg.generated.terminalAutoApproval;

    "chat.checkpoints.enabled" = true;
    "chat.checkpoints.showFileChanges" = true;
    "chat.extensionTools.enabled" = true;
  };

  fixVscodeExtensionsScript = pkgs.writers.writeNuBin "fix-vscode-extensions" (
    builtins.readFile ./fix-vscode-extensions.nu
  );

  updateVscodeSettingsScript = pkgs.writers.writeNuBin "update-vscode-settings" (
    builtins.readFile ./update-vscode-settings.nu
  );

  setupVscodeMcpScript = pkgs.writers.writeNuBin "setup-vscode-mcp" (
    builtins.readFile ./setup-vscode-mcp.nu
  );
in
{
  options = {
    programs.vscode-extended = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable VSCode configuration module";
      };

      mutableUserSettings = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether VSCode user settings should be writable at runtime.
          When true, creates a writable settings.json file instead of a read-only symlink.
          When false, uses Home Manager's immutable settings management.
        '';
      };

      mutableExtensionsDir = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether extensions can be installed or updated manually
          or by Visual Studio Code. 

          Note: Due to Home Manager's current implementation, this setting
          has limitations when used with profiles. Extensions defined in Nix
          will still be managed immutably, but VSCode can install additional
          extensions and modify some settings at runtime.
        '';
      };

      includeAgentInstructions = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to include agent instructions for GitHub Copilot.

          This creates:
          1. Base/general instructions in settings.json (uses deprecated but working
             github.copilot.chat.codeGeneration.instructions setting)
          2. Language-specific .instructions.md files in ~/.config/Code/User/ with
             applyTo patterns that automatically apply when editing specific file types

          The language-specific instructions files use the modern .instructions.md
          approach with glob patterns to match file types. These automatically apply
          without needing to manually attach them.

          Individual workspaces can override by creating .github/copilot-instructions.md
          files in their workspace root.
        '';
      };

      enableAutoApproval = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable auto-approval for Copilot tools and commands.
          WARNING: This reduces security protections. Use with caution.
        '';
      };

      additionalMarketplaceExtensions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Additional marketplace extensions to install (beyond defaults)";
        example = lib.literalExpression ''
          [
            {
              name = "lean4";
              publisher = "leanprover";
              version = "0.0.209";
              sha256 = "qkfTEeTGaMNKXNmhU1hlyn/0J38xXsFRuf6wBnAYkZI=";
            }
          ]
        '';
      };

      additionalExtensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional extensions from nixpkgs to install (beyond defaults)";
        example = lib.literalExpression ''
          with pkgs.vscode-extensions; [
            rust-lang.rust-analyzer
            ms-vscode.cpptools
          ]
        '';
      };

      additionalUserSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional user settings to merge with defaults";
        example = lib.literalExpression ''
          {
            "projectManager.git.baseFolders" = [ "~/Code" ];
            "github.copilot.enable"."rust" = true;
          }
        '';
      };

    };
  };

  config = lib.mkIf cfg.enable {
    # Enable MCP server management for VSCode
    programs.mcp.enable = true;

    warnings =
      lib.optional
        (
          builtins.hasAttr "desktopManager" config.services
          && builtins.hasAttr "plasma6" config.services.desktopManager
          && config.services.desktopManager.plasma6.enable or false
          && !(config.services.gnome.gnome-keyring.enable or false)
        )
        ''
          VS Code requires GNOME Keyring for credential storage in KDE environments.
          Add to your system configuration (not Home Manager):
            services.gnome.gnome-keyring.enable = true;
        '';

    xdg.configFile = lib.mkMerge (
      [
        (lib.optionalAttrs cfg.includeAgentInstructions {
          "Code/User/prompts/base.instructions.md" = {
            source = generateBaseInstructionFile;
          };
        })
      ]
      ++ (lib.mapAttrsToList (
        name: langCfg:
        lib.optionalAttrs (cfg.includeAgentInstructions && langCfg.enable) {
          "Code/User/prompts/${name}.instructions.md" = {
            source = generateLanguageInstructionFile name langCfg;
          };
        }
      ) agentCfg.languages)
    );

    home = {
      activation = {
        fixVscodeExtensions = lib.mkIf cfg.mutableExtensionsDir {
          after = [
            "writeBoundary"
            "reloadSystemd"
          ];
          before = [ ];
          data = ''
            ${fixVscodeExtensionsScript}/bin/fix-vscode-extensions
          '';
        };

        vscodeSettings = lib.mkIf cfg.mutableUserSettings (
          let
            mergedSettings =
              languageFormatters
              // editorSettings
              // windowSettings
              // terminalSettings
              // gitSettings
              // languageServerSettings
              // extensionSettings
              // (if cfg.includeAgentInstructions then copilotBaseInstructionsSettings else { })
              // (if cfg.enableAutoApproval then copilotAutoApprovalSettings else { })
              // cfg.additionalUserSettings;

            jsonFormat = pkgs.formats.json { };
            settingsJson = jsonFormat.generate "vscode-settings.json" mergedSettings;
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${updateVscodeSettingsScript}/bin/update-vscode-settings "${settingsJson}"
          ''
        );

        # Setup MCP servers configuration for VSCode
        setupVscodeMcpServers =
          let
            mcpCfg = config.programs.mcp;
            mcpConfigJson = builtins.toJSON {
              mcpServers = lib.mapAttrs (_name: server: {
                type = "stdio";
                command = if server.command != "" then server.command else "${lib.getExe server.package}";
                inherit (server) args;
                inherit (server) env;
              }) mcpCfg.servers;
            };
          in
          lib.mkIf (mcpCfg.enable && mcpCfg.servers != { }) (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${setupVscodeMcpScript}/bin/setup-vscode-mcp --mcp-config '${mcpConfigJson}' --scope user
            ''
          );
      };
    };
    programs.vscode = {
      enable = true;
      package = unstable.vscode;
      inherit (cfg) mutableExtensionsDir;

      profiles.default = {
        extensions =
          defaultNixpkgsExtensions
          ++ defaultMarketplaceExtensions
          ++ (mkMarketplaceExts cfg.additionalMarketplaceExtensions)
          ++ cfg.additionalExtensions;

        userSettings = lib.mkIf (!cfg.mutableUserSettings) (
          lib.mkMerge [
            languageFormatters
            editorSettings
            windowSettings
            terminalSettings
            gitSettings
            languageServerSettings
            extensionSettings
            copilotBaseInstructionsSettings
            copilotAutoApprovalSettings
            cfg.additionalUserSettings
          ]
        );
      };
    };
  };
}
