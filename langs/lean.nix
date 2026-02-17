{
  pkgs,
  ast-grep,
  tree-sitter-lean,
}:

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
  servers = {
    lean4 = {
      command = "lake";
      args = [ "serve" ];

    };
    ast-grep-lsp = ast-grep;
  };
  additionalPackages = [ pkgs.elan ];
  grammar = tree-sitter-lean.packages.${pkgs.system}.default;
}
