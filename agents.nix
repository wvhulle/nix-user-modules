{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.agents;
  langCfg = config.programs.languages;

  defaultBaseInstructions = [
    "Read the @CONTRIBUTING.md file if present to see important repository-specific guidelines."
    "Don't tell how good my ideas are. Be a critical conversation partner."
    "Use a functional and idiomatic programming style."

    "When you copy code from online sources, include a comment with the source URL."
  ];

  formatInstructionList =
    instructions:
    lib.concatStringsSep "\n" (
      lib.imap0 (i: instruction: "${toString (i + 1)}. ${instruction}") instructions
    );

  generateLanguagePrompts =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.instructions != [ ]) langCfg.languages;
      languagePrompts = lib.mapAttrsToList (name: langCfg': ''
        ## ${lib.strings.toUpper (lib.substring 0 1 name)}${lib.substring 1 (-1) name}

        ${formatInstructionList langCfg'.instructions}'') enabledLanguages;
    in
    lib.concatStringsSep "\n\n" languagePrompts;

  generateMainPrompt =
    let
      languagePromptsText = generateLanguagePrompts;
      baseInstructions = formatInstructionList cfg.baseInstructions;
    in
    ''
      # Instructions for AI Agents

      ## General rules

    ''
    + baseInstructions
    + (lib.optionalString (languagePromptsText != "") ("\n\n" + languagePromptsText));

  collectAllTerminalCommands =
    let
      globalCommands = cfg.terminalCommands;
      languageCommands = lib.foldl' (acc: lang: acc // lang.terminalCommands) { } (
        lib.attrValues (lib.filterAttrs (_: l: l.enable) langCfg.languages)
      );
    in
    globalCommands // languageCommands;

  generateTerminalAutoApproval =
    let
      allCommands = collectAllTerminalCommands;

      commandEntries = lib.flatten (
        lib.mapAttrsToList (
          _categoryName: categoryCfg:
          map (cmd: { ${cmd} = categoryCfg.autoApprove; }) categoryCfg.exactCommands
        ) allCommands
      );

      patternEntries = lib.flatten (
        lib.mapAttrsToList (
          _categoryName: categoryCfg:
          map (pattern: { ${pattern} = categoryCfg.autoApprove; }) categoryCfg.regexPatterns
        ) allCommands
      );

      allEntries = commandEntries ++ patternEntries;
    in
    lib.foldl' (acc: entry: acc // entry) { } allEntries;

  generateLanguageSkills =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.instructions != [ ]) langCfg.languages;

      skillDirs = lib.mapAttrsToList (name: langCfg': {
        inherit name;
        path = pkgs.writeTextDir "SKILL.md" ''
          ---
          name: ${name}-guidelines
          description: Guidelines for developing in `${name}`
          ---

          # Guidelines for `${name}` development

          ${formatInstructionList langCfg'.instructions}
        '';
      }) enabledLanguages;

      languageSkillsDir = pkgs.linkFarm "language-skills" skillDirs;
    in
    if cfg.skillsFolder != null then
      pkgs.symlinkJoin {
        name = "agent-skills";
        paths = [
          languageSkillsDir
          cfg.skillsFolder
        ];
      }
    else
      languageSkillsDir;

  generateLanguageSkillFiles =
    prefix:
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.instructions != [ ]) langCfg.languages;
    in
    lib.mapAttrsToList (name: langCfg': {
      name = "${prefix}/${name}/SKILL.md";
      value = {
        text = ''
          ---
          name: ${name}-guidelines
          description: Guidelines for developing in `${name}`
          ---

          # Guidelines for `${name}` development

          ${formatInstructionList langCfg'.instructions}
        '';
      };
    }) enabledLanguages;

  generateLanguageCommands =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.commands != { }) langCfg.languages;
    in
    lib.foldl' (
      acc: langName:
      let
        lang = langCfg.languages.${langName};
      in
      acc
      // (lib.mapAttrs' (
        cmdName: cmdCfg:
        lib.nameValuePair "${langName}-${cmdName}" (
          let
            frontmatter = lib.concatStringsSep "\n" (
              lib.filter (x: x != "") [
                "description: ${cmdCfg.description}"
                (lib.optionalString (
                  cmdCfg.allowedTools != [ ]
                ) "allowed-tools: ${lib.concatStringsSep ", " cmdCfg.allowedTools}")
                (lib.optionalString (cmdCfg.argumentHint != null) "argument-hint: ${cmdCfg.argumentHint}")
              ]
            );
          in
          ''
            ---
            ${frontmatter}
            ---

            ${cmdCfg.prompt}
          ''
        )
      ) lang.commands)
    ) { } (lib.attrNames enabledLanguages);

  globalTerminalCommands = {
    git-read = {
      autoApprove = true;
      exactCommands = [
        "git status"
        "git log"
        "git diff"
        "git show"
        "git branch"
        "git remote"
      ];
      regexPatterns = [ ];
    };

    system-info = {
      autoApprove = true;
      exactCommands = [
        "ps"
        "top"
        "htop"
        "free"
        "uname"
        "whoami"
        "id"
        "date"
        "uptime"
        "nft list ruleset"
        "bluetoothctl devices"
        "find"
      ];
      regexPatterns = [
        "/^systemctl\\s+(status|list-units|--failed|show)\\b/"
        "/^journalctl\\b/"
      ];
    };

    file-read = {
      autoApprove = true;
      exactCommands = [
        "pwd"
        "which"
        "whereis"
        "tree"
      ];
      regexPatterns = [
        "/^ls\\b/"
        "/^cat\\b/"
        "/^head\\b/"
        "/^tail\\b/"
        "/^grep\\b/"
        "/^find\\b/"
        "/^du\\b/"
        "/^df\\b/"
        "/^wc\\b/"
        "/^file\\b/"
      ];
    };

    network-safe = {
      autoApprove = true;
      exactCommands = [ "ping" ];
      regexPatterns = [
        "/^curl\\s+(--head|-I|--silent|-s)\\b/"
        "/^wget\\s+(--spider|-S)\\b/"
      ];
    };

    dangerous = {
      autoApprove = false;
      exactCommands = [
        "dd"
        "mkfs"
        "fdisk"
        "parted"
        "reboot"
        "shutdown"
        "poweroff"
      ];
      regexPatterns = [
        "/rm\\s+.*-rf?\\s+/"
        "/rm\\s+-[^\\s]*r[^\\s]*f/"
        "/dangerous/"
        "/\\.(sh|bash|ps1)$/"
        "/\\|\\s*sh\\b/"
        "/\\|\\s*bash\\b/"
      ];
    };
  };

  terminalCommandType = lib.types.submodule {
    options = {
      autoApprove = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to auto-approve this command category";
      };

      exactCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Literal command strings for exact matching";
      };

      regexPatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Regular expression patterns for flexible matching";
      };
    };
  };
in
{
  options.programs.agents = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable shared AI agent configuration";
    };

    baseInstructions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultBaseInstructions;
      description = "Base instructions for AI agents in order of importance";
    };

    skillsFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a folder containing custom skill definitions to merge with language skills";
    };

    terminalCommands = lib.mkOption {
      type = lib.types.attrsOf terminalCommandType;
      default = globalTerminalCommands;
      description = "Global terminal command categories for auto-approval (language-agnostic)";
    };

    terminalCommandType = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      internal = true;
      default = terminalCommandType;
      description = "Terminal command type for use by other modules";
    };

    languageSkills = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      default = generateLanguageSkills;
      description = "Generated language skills directory for AI agents";
    };

    languageSkillFiles = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      internal = true;
      default = generateLanguageSkillFiles;
      description = "Function that generates language skill files for home.file usage. Takes a prefix path as argument.";
    };

    languageCommands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      internal = true;
      default = generateLanguageCommands;
      description = "Generated language commands for AI agents";
    };

    generated = {
      mainPrompt = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        internal = true;
        default = generateMainPrompt;
        description = "Generated main prompt text (for Claude's CLAUDE.md)";
      };

      terminalAutoApproval = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        internal = true;
        default = generateTerminalAutoApproval;
        description = "Generated terminal auto-approval configuration for VSCode";
      };
    };
  };

  config = lib.mkIf cfg.enable { };
}
