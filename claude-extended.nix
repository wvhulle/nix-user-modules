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

  formatInstructionList =
    instructions:
    lib.concatStringsSep "\n" (
      lib.imap0 (i: instruction: "${toString (i + 1)}. ${instruction}") instructions
    );

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

      skillsDir = agentCfg.languageSkills;

      commands = agentCfg.languageCommands;

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
