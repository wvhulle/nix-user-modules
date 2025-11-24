# Source: https://github.com/natsukium/mcp-servers-nix/blob/main/modules/playwright.nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.playwright;

  # Generate MCP configuration in Claude Code format
  mcpConfig = pkgs.writeText "mcp-config.json" (
    builtins.toJSON {
      mcpServers = {
        playwright = {
          command = "${cfg.package}/bin/mcp-server-playwright";
          args = [
            "--executable-path"
            "${cfg.executable}"
          ];
          env = { };
        };
      };
    }
  );
in
{
  options.programs.playwright = {
    enable = lib.mkEnableOption (lib.mdDoc "Enable playwright MCP server");

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/playwright.nix { };
      description = lib.mdDoc "The playwright package to use";
    };

    executable = lib.mkOption {
      type = lib.types.path;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          lib.getExe pkgs.google-chrome
        else
          lib.getExe pkgs.chromium;
      description = lib.mdDoc "The executable path for browser";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [
        cfg.package
      ];

      # Create temporary MCP config file
      file.".mcp-playwright.json" = {
        source = mcpConfig;
      };

      # Setup MCP configuration via activation script
      activation.setupPlaywrightMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.nushell}/bin/nu ${./setup-claude-mcp.nu} --mcp-config ~/.mcp-playwright.json
      '';
    };
  };
}
