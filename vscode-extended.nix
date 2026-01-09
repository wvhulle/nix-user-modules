{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.vscode-extended;
  agentCfg = config.programs.agents;
  langsCfg = config.programs.languages;
  fontsCfg = config.programs.typography;

  capitalize = name: lib.strings.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;

  generateLanguagePattern =
    extensions:
    if builtins.length extensions == 0 then
      "**"
    else if builtins.length extensions == 1 then
      "*.${builtins.head extensions}"
    else
      "*.{${lib.concatStringsSep "," extensions}}";
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

  # Extensions not available in pkgs.vscode-extensions
  defaultMarketplaceExtensions = mkMarketplaceExts [
    {
      publisher = "ast-grep";
      name = "ast-grep-vscode";
      version = "0.1.18";
      sha256 = "sha256-zZ1B5Q5cdfJxbz7uRRyWP8eUZW24Gsezqi+Lx03eioo=";
    }
    {
      publisher = "constneo";
      name = "vscode-nushell-format";
      version = "0.1.9";
      sha256 = "sha256-L6VV5aY7NYDsMyQIBvWf9ifczJtFSzQk+D5mDfIJKDM=";
    }
    {
      publisher = "ms-vscode";
      name = "vscode-websearchforcopilot";
      version = "0.2.2025121801";
      sha256 = "sha256-oZKpXo1YTUh0JnAS5yqVQZzyrNsXkXiHTDm+VxTWG5U=";
    }
    {
      publisher = "willemvanhulle";
      name = "nu-lint";
      version = "0.0.13";
      sha256 = "sha256-76KK85Jd34U9VG+0RKImoEblcr7z1vqje2LdhbdSs/g=";
    }
    {
      publisher = "activitywatch";
      name = "aw-watcher-vscode";
      version = "0.5.0";
      sha256 = "sha256-OrdIhgNXpEbLXYVJAx/jpt2c6Qa5jf8FNxqrbu5FfFs=";
    }
  ];

  defaultNixpkgsExtensions = with pkgs.vscode-extensions; [

    quicktype.quicktype

    # Previously from marketplace, now available in nixpkgs:
    anthropic.claude-code

    alefragnani.project-manager
    codezombiech.gitignore
    jnoortheen.nix-ide

    foxundermoon.shell-format
    bierner.markdown-mermaid
    charliermarsh.ruff
    christian-kohler.path-intellisense
    continue.continue
    davidanson.vscode-markdownlint
    dbaeumer.vscode-eslint
    denoland.vscode-deno
    ecmel.vscode-html-css
    esbenp.prettier-vscode
    fabiospampinato.vscode-open-in-github
    file-icons.file-icons
    formulahendry.auto-rename-tag
    github.copilot
    github.copilot-chat
    github.github-vscode-theme
    github.vscode-github-actions
    github.vscode-pull-request-github
    gruntfuggly.todo-tree
    haskell.haskell
    haskell.haskell
    justusadam.language-haskell
    mechatroner.rainbow-csv
    mhutchie.git-graph
    mkhl.direnv
    ms-azuretools.vscode-docker
    ms-python.python
    ms-python.vscode-pylance
    ms-vscode-remote.remote-ssh
    ms-vscode-remote.remote-ssh-edit
    ms-vscode.cmake-tools
    llvm-vs-code-extensions.vscode-clangd
    ms-vsliveshare.vsliveshare
    myriad-dreamin.tinymist
    pkief.material-icon-theme
    rust-lang.rust-analyzer
    streetsidesoftware.code-spell-checker
    svelte.svelte-vscode
    tamasfe.even-better-toml
    tekumara.typos-vscode
    thenuprojectcontributors.vscode-nushell-lang
    timonwong.shellcheck
    tomoki1207.pdf
    vadimcn.vscode-lldb
    vscode-icons-team.vscode-icons
    wholroyd.jinja
    wix.vscode-import-cost
  ];

  defaultSettings = {
    editor = {
      cursorBlinking = "smooth";
      cursorSmoothCaretAnimation = "on";
      fontFamily = "'${fontsCfg.editor.name}', '${fontsCfg.terminal.name}', monospace";
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
      preferredDarkColorTheme = config.programs.darkMode.apps.vscode.dark;
      preferredLightColorTheme = config.programs.darkMode.apps.vscode.light;
      editor = {
        enablePreview = false;
        highlightModifiedTabs = true;
      };
      iconTheme = "vscode-icons";
      layoutControl.enabled = false;
      navigationControl.enabled = false;
    };

    terminal.integrated = {
      fontFamily = fontsCfg.terminal.name;
      fontSize = fontsCfg.sizes.terminal;
      smoothScrolling = true;
      defaultProfile.linux = "bash";
      commandsToSkipShell = [
        "-workbench.action.quickOpen" # Ctrl+R in some contexts
      ];
      sendKeybindingsToShell = true;
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

    clangd = {
      path = "${pkgs.clang-tools}/bin/clangd";
      arguments = [
        "--background-index"
        "--clang-tidy"
        "--completion-style=detailed"
        "--header-insertion=never"
        "--suggest-missing-includes"
      ];
    };

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

    claudeCode = {
      claudeProcessWrapper = "${claudeProcessWrapper}";
      allowDangerouslySkipPermissions = true;
      preferredLocation = "panel";
    };

    chat = {
      useClaudeSkills = true;
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
    "[c]" = {
      editor = {
        defaultFormatter = "llvm-vs-code-extensions.vscode-clangd";
        formatOnSave = true;
      };
    };
    "[cpp]" = {
      editor = {
        defaultFormatter = "llvm-vs-code-extensions.vscode-clangd";
        formatOnSave = true;
      };
    };
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

  generateLanguageSkills =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.instructions != [ ]) langsCfg.languages;
    in
    lib.mapAttrsToList (name: langCfg': {
      name = ".github/skills/${name}/SKILL.md";
      value = {
        text = ''
          ---
          name: ${name}-guidelines
          description: ${capitalize name} development: ${lib.concatStringsSep ", " (lib.take 3 langCfg'.instructions)}
          ---

          # ${capitalize name} Guidelines

          ${lib.concatStringsSep "\n" (
            lib.imap0 (i: instr: "${toString (i + 1)}. ${instr}") langCfg'.instructions
          )}
        '';
      };
    }) enabledLanguages;

  generateLanguagePrompts =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.commands != { }) langsCfg.languages;

      generatePromptFile =
        langName: cmdName: cmdCfg: location:
        let
          frontmatter = lib.concatStringsSep "\n" (
            lib.filter (x: x != "") [
              "description: ${cmdCfg.description}"
              (lib.optionalString (cmdCfg.argumentHint != null) "argument-hint: ${cmdCfg.argumentHint}")
            ]
          );
        in
        {
          name = "${location}/${langName}/${cmdName}.prompt.md";
          value = {
            text = ''
              ---
              ${frontmatter}
              ---

              ${cmdCfg.prompt}
            '';
          };
        };
    in
    lib.flatten (
      lib.mapAttrsToList (
        langName: lang:
        lib.flatten (
          lib.mapAttrsToList (cmdName: cmdCfg: [
            # Workspace prompts (.github/prompts)
            (generatePromptFile langName cmdName cmdCfg ".github/prompts")
          ]) lang.commands
        )
      ) enabledLanguages
    );

  generateUserPrompts =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.commands != { }) langsCfg.languages;
    in
    lib.flatten (
      lib.mapAttrsToList (
        langName: lang:
        lib.mapAttrsToList (
          cmdName: cmdCfg:
          let
            frontmatter = lib.concatStringsSep "\n" (
              lib.filter (x: x != "") [
                "description: ${cmdCfg.description}"
                (lib.optionalString (cmdCfg.argumentHint != null) "argument-hint: ${cmdCfg.argumentHint}")
              ]
            );
          in
          {
            name = "Code/User/prompts/${langName}-${cmdName}.prompt.md";
            value = {
              text = ''
                ---
                ${frontmatter}
                ---

                ${cmdCfg.prompt}
              '';
            };
          }
        ) lang.commands
      ) enabledLanguages
    );

  claudeProcessWrapper = pkgs.writeShellScript "claude-wrapper" ''
    exec ${pkgs.claude-code}/bin/claude "$@"
  '';
in
{
  options = {
    programs.vscode-extended = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable VSCode configuration module";
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
            llvm-vs-code-extensions.vscode-clangd
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

    home.file = lib.mkMerge (
      (map (skill: { ${skill.name} = skill.value; }) generateLanguageSkills)
      ++ (map (prompt: { ${prompt.name} = prompt.value; }) generateLanguagePrompts)
    );

    xdg.configFile = lib.mkMerge (
      [
        (lib.optionalAttrs cfg.includeAgentInstructions {
          "Code/User/prompts/base.instructions.md" = {
            source = generateBaseInstructionFile;
          };
        })
      ]
      ++ (lib.mapAttrsToList (
        name: langCfg':
        lib.optionalAttrs (cfg.includeAgentInstructions && langCfg'.enable) {
          "Code/User/prompts/${name}.instructions.md" = {
            source = generateLanguageInstructionFile name langCfg';
          };
        }
      ) langsCfg.languages)
      ++ (map (prompt: { ${prompt.name} = prompt.value; }) generateUserPrompts)
    );

    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      mutableExtensionsDir = false;
      profiles.default = {
        enableMcpIntegration = true;
        extensions = defaultNixpkgsExtensions ++ defaultMarketplaceExtensions ++ cfg.additionalExtensions;

        userSettings = flattenVscodeSettings (
          lib.recursiveUpdate defaultSettings cfg.additionalUserSettings
        );
      };
    };
  };
}
