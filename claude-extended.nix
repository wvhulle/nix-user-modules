{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-extended;
  agentCfg = config.programs.agents;
  mcpCfg = config.programs.mcp;
  langCfg = config.programs.languages;

  formatInstructionList =
    instructions:
    lib.concatStringsSep "\n" (
      lib.imap0 (i: instruction: "${toString (i + 1)}. ${instruction}") instructions
    );

  capitalizeFirst = name: lib.strings.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;

  generateSkillDescription =
    instructions:
    let
      firstThree = lib.take 3 instructions;
      shortened = map (
        s:
        let
          len = lib.stringLength s;
        in
        if len > 50 then (lib.substring 0 47 s) + "..." else s
      ) firstThree;
    in
    lib.concatStringsSep ", " shortened;

  generateLanguageSkills =
    let
      enabledLanguages = lib.filterAttrs (_: l: l.enable && l.instructions != [ ]) langCfg.languages;
    in
    lib.mapAttrs' (
      name: langCfg':
      lib.nameValuePair name ''
        ---
        name: ${name}-guidelines
        description: ${capitalizeFirst name} development: ${generateSkillDescription langCfg'.instructions}
        ---

        # ${capitalizeFirst name} Guidelines

        ${formatInstructionList langCfg'.instructions}
      ''
    ) enabledLanguages;

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

  generateBaseMemory = ''
    # Instructions for AI Agents

    ## General rules

    ${formatInstructionList agentCfg.baseInstructions}
  '';

  generateAllowList =
    let
      terminalConfig = agentCfg.generated.terminalAutoApproval;
      approvedCommands = lib.filterAttrs (_: approved: approved) terminalConfig;
    in
    lib.filter (x: x != null) (
      lib.mapAttrsToList (
        cmd: _: if lib.hasPrefix "/" cmd && lib.hasSuffix "/" cmd then null else "Bash(${cmd})"
      ) approvedCommands
    );

  generateDenyList =
    let
      terminalConfig = agentCfg.generated.terminalAutoApproval;
      deniedCommands = lib.filterAttrs (_: approved: !approved) terminalConfig;
    in
    lib.mapAttrsToList (cmd: _: "Bash(${cmd}:*)") deniedCommands;

  transformMcpServers = lib.mapAttrs (
    _name: server:
    {
      type = "stdio";
      inherit (server) command;
      inherit (server) args;
    }
    // lib.optionalAttrs (server ? env && server.env != { }) { inherit (server) env; }
  ) mcpCfg.servers;
in
{
  options.programs.claude-extended = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Claude Code configuration with agents integration";
    };

    statusline = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to enable Claude Code statusline with ccusage integration";
          };
        };
      };
      default = { };
      description = "Statusline configuration for Claude Code";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;

      memory.text = generateBaseMemory;

      skills = generateLanguageSkills;

      commands = generateLanguageCommands;

      settings = {
        permissions = {
          allow = generateAllowList;
          deny = generateDenyList;
        };
      }
      // lib.optionalAttrs cfg.statusline.enable {
        statusLine = {
          type = "command";
          command = "${./claude-code-statusline.nu}";
        };
      };

      mcpServers = transformMcpServers;
    };

    home.packages = [ pkgs.nodejs ];
  };
}
