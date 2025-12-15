{
  lib,
  config,
  pkgs,
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

  # Flatten nested attrsets to VSCode dot-notation settings
  # e.g., { editor.fontSize = 14; } -> { "editor.fontSize" = 14; }
  # Language overrides like "[nix]" preserve their bracket key but flatten inner contents
  # Map-like settings (autoApprove, enable) preserve their object structure
  flattenVscodeSettings =
    let
      isLeaf = v: !builtins.isAttrs v || builtins.isList v || lib.isDerivation v;

      isLanguageOverride = name: lib.hasPrefix "[" name && lib.hasSuffix "]" name;

      # Settings that expect an object/map value (not to be flattened further)
      # These are the final keys whose values should remain as objects
      isMapSetting =
        name:
        builtins.elem name [
          "autoApprove"
          "enable"
          "linux"
          "osx"
          "windows"
        ];

      go =
        prefix: attrs:
        lib.foldlAttrs (
          acc: name: value:
          let
            fullKey = if prefix == "" then name else "${prefix}.${name}";
          in
          if isLanguageOverride name then
            acc // { ${name} = if builtins.isAttrs value then go "" value else value; }
          else if isMapSetting name then
            # Preserve map-like settings as objects
            acc // { ${fullKey} = value; }
          else if isLeaf value then
            acc // { ${fullKey} = value; }
          else
            acc // (go fullKey value)
        ) { } attrs;
    in
    go "";

  defaultMarketplaceExtensions = with pkgs.vscode-marketplace; [
    anthropic.claude-code
    ziyasal.vscode-open-in-github
    jnoortheen.nix-ide
    ms-vscode.vscode-websearchforcopilot
    codezombiech.gitignore
    willemvanhulle.nu-lint
    alefragnani.project-manager
    quicktype.quicktype
    foxundermoon.shell-format
    ast-grep.ast-grep-vscode
    leanprover.lean4
    constneo.vscode-nushell-format
  ];

  defaultNixpkgsExtensions = with pkgs.vscode-extensions; [
    streetsidesoftware.code-spell-checker
    bierner.markdown-mermaid
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
    charliermarsh.ruff
    continue.continue
    denoland.vscode-deno
    github.vscode-github-actions
    github.vscode-pull-request-github
    mhutchie.git-graph
    ms-azuretools.vscode-docker
    rust-lang.rust-analyzer
    svelte.svelte-vscode
    wholroyd.jinja
    wix.vscode-import-cost
  ];

  defaultSettings = {
    editor = {
      cursorBlinking = "smooth";
      cursorSmoothCaretAnimation = "on";
      fontFamily = fontsCfg.editorFontFamily;
      fontSize = fontsCfg.sizes.editor;
      fontLigatures = true;
      formatOnSave = true;
      smoothScrolling = true;
      wordWrap = "on";
    };

    window = {
      autoDetectColorScheme = true;
      titleBarStyle = "native";
      commandCenter = false;
      menuBarVisibility = "toggle";
    };

    workbench = {
      list.smoothScrolling = true;
      preferredDarkColorTheme = "GitHub Dark Default";
      preferredLightColorTheme = "GitHub Light Default";
      editor = {
        enablePreview = false;
        highlightModifiedTabs = true;
      };
      iconTheme = "vscode-icons";
      layoutControl.enabled = false;
      navigationControl.enabled = false;
    };

    terminal.integrated = {
      fontFamily = fontsCfg.terminalFontFamily;
      fontSize = fontsCfg.sizes.terminal;
      smoothScrolling = true;
      defaultProfile.linux = "bash";
      profiles.linux = {
        fish = {
          path = "${pkgs.fish}/bin/fish";
          icon = "terminal-bash";
        };
        nushell = {
          path = "${pkgs.nushell}/bin/nu";
          icon = "terminal-powershell";
        };
        bash = {
          path = "${pkgs.bash}/bin/bash";
          icon = "terminal-bash";
        };
      };
    };

    git = {
      autofetch = true;
      confirmSync = false;
      openRepositoryInParentFolders = "never";
    };

    nix = {
      enableLanguageServer = true;
      serverPath = "${pkgs.nil}/bin/nil";
      formatterPath = "nixfmt";

    };

    rust-analyzer = {
      check.command = "clippy";
      completion = {
        fullFunctionSignatures.enable = true;
        postfix.enable = false;
        privateEditable.enable = true;
      };
      diagnostics.enable = false;
      imports.preferNoStd = true;
      lens.references.method.enable = true;
    };

    python.analysis.typeCheckingMode = "strict";

    direnv.restart.automatic = true;

    extensions = {
      autoCheckUpdates = false;
      autoUpdate = false;
    };

    typos = {
      path = "${pkgs.typos-lsp}/bin/typos-lsp";
      diagnosticSeverity = "Information";
    };

    markdownlint.config.extends = null;

    evenBetterToml = {
      formatter = {
        reorderKeys = true;
        reorderArrays = false;
        reorderInlineTables = true;
      };
      taplo.extraArgs = [
        "--option"
        "reorder_keys=true"
        "--option"
        "reorder_arrays=true"
      ];
    };

    githubPullRequests = {
      terminalLinksHandler = "github";
      pullBranch = "never";
      experimental = {
        chat = true;
        notificationsView = true;
        useQuickChat = true;
      };
    };

    github.copilot = {
      chat = {
        codesearch.enabled = true;
        editor.temporalContext.enabled = true;
        edits.temporalContext.enabled = true;
        generateTests.codeLens = true;
        newWorkspaceCreation.enabled = true;
        search.semanticTextResults = true;
        agent = {
          thinkingTool = true;
          runTasks = true;
          autoFix = true;
        };
        useProjectTemplates = false;
        codeGeneration.useInstructionFiles = true;
      };
      nextEditSuggestions = {
        enabled = true;
        fixes = true;
      };
    };

    chat = {
      agent = {
        enabled = true;
        maxRequests = 100000;
      };
      tools = {
        global.autoApprove = true;
        edits.autoApprove = {
          "**/*" = true;
          "**/.vscode/*.json" = false;
          "**/.env" = false;
          "**/configuration.nix" = false;
          "**/hardware-configuration.nix" = false;
        };
        terminal.autoApprove = agentCfg.generated.terminalAutoApproval;
      };
      checkpoints = {
        enabled = true;
        showFileChanges = true;
      };
      extensionTools.enabled = true;
    };

    projectManager.git.baseFolders = cfg.projectManagerBaseFolders;

    "[css]".editor.defaultFormatter = "vscode.css-language-features";
    "[html]".editor.defaultFormatter = "vscode.html-language-features";
    "[javascript]".editor.defaultFormatter = "vscode.typescript-language-features";
    "[json]".editor.defaultFormatter = "vscode.json-language-features";
    "[jsonc]".editor.defaultFormatter = "vscode.json-language-features";
    "[markdown]".editor.defaultFormatter = "DavidAnson.vscode-markdownlint";
    "[nix]".editor.defaultFormatter = "jnoortheen.nix-ide";
    "[nushell]" = {
      editor = {
        defaultFormatter = "constneo.vscode-nushell-format";
        formatOnSave = true;
      };
    };
    "[rust]".editor.defaultFormatter = "rust-lang.rust-analyzer";
    "[scss]".editor.defaultFormatter = "vscode.css-language-features";
    "[python]".editor.defaultFormatter = "charliermarsh.ruff";
    "[c]".editor.formatOnSave = false;
    "[cpp]".editor.formatOnSave = false;
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

      additionalExtensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          Additional extensions to install (beyond defaults).
          Can include extensions from pkgs.vscode-extensions (nixpkgs) or
          pkgs.vscode-marketplace (nix-vscode-extensions overlay).
        '';
        example = lib.literalExpression ''
          (with pkgs.vscode-marketplace; [
            leanprover.lean4
          ])
          ++ (with pkgs.vscode-extensions; [
            rust-lang.rust-analyzer
            ms-vscode.cpptools
          ])
        '';
      };

      additionalUserSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Additional user settings to merge with defaults.
          Settings can be specified as nested attribute sets which will be
          flattened to dot-notation format for VSCode.
        '';
        example = lib.literalExpression ''
          {
            editor.fontSize = 16;
            terminal.integrated.fontSize = 14;
            github.copilot.enable = {
              "*" = true;
              rust = false;
              python = false;
            };
          }
        '';
      };

      enableCopilotExperimentalFeatures = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable experimental GitHub Copilot and PR features";
      };

      projectManagerBaseFolders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "${config.home.homeDirectory}/Code" ];
        description = "Base folders for Project Manager extension";
      };

    };
  };

  config = lib.mkIf cfg.enable {
    # Enable MCP server management for VSCode
    programs.mcp-extended.enable = true;

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

        # Setup MCP servers configuration for VSCode
        setupVscodeMcpServers =
          let
            mcpCfg = config.programs.mcp-extended;
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
      package = pkgs.vscode;
      inherit (cfg) mutableExtensionsDir;

      profiles.default = {
        extensions = defaultNixpkgsExtensions ++ defaultMarketplaceExtensions ++ cfg.additionalExtensions;

        userSettings = lib.mkIf (!cfg.mutableUserSettings) (
          flattenVscodeSettings (lib.recursiveUpdate defaultSettings cfg.additionalUserSettings)
        );
      };
    };
  };
}
