{ pkgs }:

{
  extensions = [ "lean" ];
  instructions = [
    "Use `lean-lsp-mcp` MCP server for goals/diagnostics"
    "Replace `sorry` step-by-step"
    "Try `exact?` then `apply?` before searching"
    "Use `lake build`, avoid `lake clean`"
  ];
  scope = "source.lean";
  fileTypes = [ "lean" ];
  roots = [
    ".git"
    "lakefile.lean"
    "lean-toolchain"
  ];
  servers.lean4 = {
    command = "lake";
    args = [ "serve" ];

  };
  additionalPackages = [ pkgs.elan ];
}
