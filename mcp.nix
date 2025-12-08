{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.mcp-extended;

  mcpServerType = lib.types.submodule {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "The MCP server package to install";
      };

      command = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Override the command to run (defaults to package's main executable)";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "--verbose"
          "--port"
          "8080"
        ];
        description = "Command-line arguments to pass to the MCP server";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          LOG_LEVEL = "debug";
        };
        description = "Environment variables to set for the MCP server";
      };
    };
  };
in
{
  options.programs.mcp-extended = {
    enable = lib.mkEnableOption "MCP (Model Context Protocol) server management";

    servers = lib.mkOption {
      type = lib.types.attrsOf mcpServerType;
      default =
        let
          context7Pkg = pkgs.callPackage ./packages/context7.nix { };
          githubPkg = pkgs.callPackage ./packages/github-mcp-server.nix { };
          playwrightPkg = pkgs.callPackage ./packages/playwright.nix { };
          browserExecutable =
            if pkgs.stdenv.hostPlatform.isDarwin then
              lib.getExe pkgs.google-chrome
            else
              lib.getExe pkgs.chromium;
        in
        {
          context7 = {
            package = context7Pkg;
            command = "${lib.getExe context7Pkg}";
            args = [ ];
            env = { };
          };

          github = {
            package = githubPkg;
            command = "${lib.getExe githubPkg}";
            args = [ "stdio" ];
            env = {
              # Token is obtained from gh CLI at runtime via command substitution
              GITHUB_PERSONAL_ACCESS_TOKEN = "$(${pkgs.gh}/bin/gh auth token 2>/dev/null || echo \${GITHUB_PERSONAL_ACCESS_TOKEN:-})";
            };
          };

          playwright = {
            package = playwrightPkg;
            command = "${lib.getExe playwrightPkg}";
            args = [
              "--executable-path"
              "${browserExecutable}"
            ];
            env = { };
          };
        };

      description = "Attribute set of MCP servers to configure";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mapAttrsToList (_name: server: server.package) cfg.servers;
  };
}
