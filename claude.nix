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
    # Install required packages for ccstatusline
    home.packages = with pkgs; [
      nodejs
      jq # For JSON manipulation
    ];

    home.file = {
      # Main CLAUDE.md file - use shared agent configuration
      ".claude/CLAUDE.md".text = agentCfg.generated.mainPrompt;

      # Claude Code settings.json with auto-approval configuration
      ".claude/settings.json".text =
        let
          # Build the configuration object conditionally
          baseConfig = {
            # Terminal auto-approval using shared agent configuration
            permissions = {
              allow =
                # Convert terminal auto-approval to Claude Code Bash permission format
                let
                  terminalConfig = agentCfg.generated.terminalAutoApproval;
                  # Filter for commands that should be auto-approved (true)
                  approvedCommands = lib.filterAttrs (_cmd: approved: approved) terminalConfig;
                  # Convert to Claude Code Bash permission format: "Bash(command)"
                  bashPermissions = lib.mapAttrsToList (
                    cmd: _:
                    # Handle regex patterns vs literal commands
                    if lib.hasPrefix "/" cmd && lib.hasSuffix "/" cmd then
                      null # Skip regex patterns for now - Claude Code doesn't support regex in allow rules
                    else
                      "Bash(${cmd})"
                  ) approvedCommands;
                in
                lib.filter (x: x != null) bashPermissions;

              deny =
                # Convert denied commands to Claude Code format
                let
                  terminalConfig = agentCfg.generated.terminalAutoApproval;
                  # Filter for commands that should be denied (false)
                  deniedCommands = lib.filterAttrs (_cmd: approved: !approved) terminalConfig;
                  # Convert to Claude Code Bash permission format
                  bashDenials = lib.mapAttrsToList (cmd: _: "Bash(${cmd}:*)") deniedCommands;
                in
                bashDenials;
            };
          };

          # Add statusline if enabled
          finalConfig =
            baseConfig
            // lib.optionalAttrs cfg.statusline.enable {
              statusLine = {
                type = "command";
                command = "${statuslineScript}/bin/claude-code-statusline";
              };
            };
        in
        # Use jq to pretty-print the JSON
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
