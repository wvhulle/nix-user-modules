{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  agentCfg = config.programs.agents;
  mcpCfg = config.programs.mcp-extended;

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
    # Enable MCP server management
    programs.mcp-extended.enable = true;

    home = {
      packages = with pkgs; [
        nodejs
        jq
      ];

      file = {
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

      # Setup MCP servers configuration for Claude
      activation.setupClaudeMcpServers =
        let
          mcpConfigJson = builtins.toJSON {
            mcpServers = lib.mapAttrs (_name: server: {
              command = if server.command != "" then server.command else "${lib.getExe server.package}";
              inherit (server) args;
              inherit (server) env;
            }) mcpCfg.servers;
          };

          setupScript = pkgs.writers.writeNuBin "setup-claude-mcp" (builtins.readFile ./setup-claude-mcp.nu);
        in
        lib.mkIf (mcpCfg.servers != { }) (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${setupScript}/bin/setup-claude-mcp --mcp-config '${mcpConfigJson}'
          ''
        );
    };
  };
}
