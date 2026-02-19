{
  pkgs,
  ast-grep,
  tree-sitter-lean,
}:

let
  grammar = tree-sitter-lean.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
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
    lean4_lsp = {
      command = "lake";
      args = [
        "serve"
        "--"
      ];
    };
    ast-grep-lsp = ast-grep;
  };
  additionalPackages = [ pkgs.elan ];
  grammar.package = grammar;
  queriesPath = tree-sitter-lean + "/queries";
}
