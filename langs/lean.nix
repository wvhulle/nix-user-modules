{
  pkgs,
  ast-grep,
  tree-sitter-lean,
}:

let
  grammar = tree-sitter-lean.packages.${pkgs.stdenv.hostPlatform.system}.grammar;
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
    lean4 = {
      command = "lake";
      args = [ "serve" ];
    };
    ast-grep-lsp = ast-grep;
  };
  additionalPackages = [ pkgs.elan ];
  grammar = {
    name = "lean";
    package = grammar;
  };
  queries = {
    highlights = "${tree-sitter-lean}/queries/highlights.scm";
    folds = "${tree-sitter-lean}/queries/folds.scm";
    locals = "${tree-sitter-lean}/queries/locals.scm";
    injections = "${tree-sitter-lean}/queries/injections.scm";
  };
}
