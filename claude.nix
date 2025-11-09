{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  agentCfg = config.programs.agents;

  statuslineScript = pkgs.writers.writeNuBin "claude-code-statusline" ''
    ^npx ccusage@latest statusline
  '';
in
{
  options = {
    programs.claude = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable Claude AI assistant configuration";
      };

      statusline = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable Claude Code statusline with ccusage integration";
            };

          };
        };
        default = { };
        description = "Statusline configuration for Claude Code";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      nodejs
      jq
    ];

    home.file = {
      ".claude/CLAUDE.md".text = agentCfg.generated.mainPrompt;

      ".claude/settings.json".text =
        let
          baseConfig = {
            permissions = {
              allow =
                let
                  terminalConfig = agentCfg.generated.terminalAutoApproval;
                  # Filter for commands that should be auto-approved (true)
                  approvedCommands = lib.filterAttrs (_cmd: approved: approved) terminalConfig;
                  # Convert to Claude Code Bash permission format: "Bash(command)"
                  bashPermissions = lib.mapAttrsToList (
                    cmd: _: if lib.hasPrefix "/" cmd && lib.hasSuffix "/" cmd then null else "Bash(${cmd})"
                  ) approvedCommands;
                in
                lib.filter (x: x != null) bashPermissions;

              deny =
                let
                  terminalConfig = agentCfg.generated.terminalAutoApproval;
                  # Filter for commands that should be denied (false)
                  deniedCommands = lib.filterAttrs (_cmd: approved: !approved) terminalConfig;
                  bashDenials = lib.mapAttrsToList (cmd: _: "Bash(${cmd}:*)") deniedCommands;
                in
                bashDenials;
            };
          };

          finalConfig =
            baseConfig
            // lib.optionalAttrs cfg.statusline.enable {
              statusLine = {
                type = "command";
                command = "${statuslineScript}/bin/claude-code-statusline";
              };
            };
        in
        builtins.readFile (
          pkgs.runCommand "claude-settings.json"
            {
              buildInputs = [ pkgs.jq ];
              passAsFile = [ "jsonContent" ];
              jsonContent = builtins.toJSON finalConfig;
            }
            ''
              jq '.' < "$jsonContentPath" > $out
            ''
        );
    };

  };
}
