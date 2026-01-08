{ pkgs }:

{
  extensions = [ "lean" ];
  instructions = [
    "Use `lean-lsp-mcp` MCP server for goals/diagnostics when available"
    "Replace `sorry` step-by-step in tests"
    "Try `exact?` and then `apply?` before searching elsewhere"
    "Use `lake build` and avoid `lake clean`"
    "Keep functions computable when possible"
    "Use problem decomposition for complex proofs"
    "Leverage existing mathlib theorems before creating new ones"
    "Provide counterexamples when proofs fail"
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
