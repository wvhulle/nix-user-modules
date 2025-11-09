{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.agents;

  instructData = import ./instruct.nix;
  approvalData = import ./approve.nix;

  formatInstructionList =
    instructions:
    lib.concatStringsSep "\n" (
      lib.imap0 (i: instruction: "${toString (i + 1)}. ${instruction}") instructions
    );

  generateLanguagePrompts =
    languages:
    let
      enabledLanguagePrompts = lib.mapAttrsToList (
        name: langCfg:
        lib.optionalString langCfg.enable ''
          ## ${lib.strings.toUpper (lib.substring 0 1 name)}${lib.substring 1 (-1) name}

          ${formatInstructionList langCfg.instructions}''
      ) languages;
    in
    lib.concatStringsSep "\n\n" (lib.filter (s: s != "") enabledLanguagePrompts);

  generateMainPrompt =
    let
      languagePromptsText = generateLanguagePrompts cfg.languages;
      baseInstructions = formatInstructionList cfg.baseInstructions;
    in
    ''
      # Instructions for AI Agents

      ## General rules

    ''
    + baseInstructions
    + (lib.optionalString (languagePromptsText != "") ("\n\n" + languagePromptsText));

  generateTerminalAutoApproval =
    let
      commandEntries = lib.flatten (
        lib.mapAttrsToList (
          _categoryName: categoryCfg:
          map (cmd: { ${cmd} = categoryCfg.autoApprove; }) categoryCfg.exactCommands
        ) cfg.terminalCommands
      );

      patternEntries = lib.flatten (
        lib.mapAttrsToList (
          _categoryName: categoryCfg:
          map (pattern: { ${pattern} = categoryCfg.autoApprove; }) categoryCfg.regexPatterns
        ) cfg.terminalCommands
      );

      allEntries = commandEntries ++ patternEntries;
    in
    lib.foldl' (acc: entry: acc // entry) { } allEntries;
in
{
  options = {
    programs.agents = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable shared AI agent configuration";
      };

      baseInstructions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = instructData.baseInstructions;
        description = "Base instructions for AI agents in order of importance";
      };

      languages = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to enable this language-specific configuration";
              };

              extensions = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "File extensions for this language (without the dot)";
              };

              instructions = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Language-specific instructions in order of importance";
              };
            };
          }
        );
        default = instructData.languages;
        description = "Language-specific AI agent configurations";
      };

      terminalCommands = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              autoApprove = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to auto-approve this command category";
              };

              exactCommands = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Literal command strings for exact matching.
                  Examples: "mkdir", "git status", "cargo test"
                  Commands are matched as-is, with any arguments allowed.
                '';
              };

              regexPatterns = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Regular expression patterns wrapped in forward slashes for flexible matching.
                  Examples: "/^git (status|show\\b.*)$/", "/dangerous/", "/\\.(sh|bash|ps1)$/"
                  Patterns are matched against subcommands by default in VS Code.
                '';
              };
            };
          }
        );
        default = approvalData.terminalCommands;
        description = "Terminal command categories for auto-approval configuration";
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
  };

  config = lib.mkIf cfg.enable { };
}
