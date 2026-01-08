{ pkgs, typosServer }:

{
  scope = "source.markdown";
  extensions = [
    "md"
    "markdown"
  ];
  instructions = [
    "Do not use deeply nested sub-sections or sub-headings."
    "The ratio of semantic content to layout should be high."
    "Use YAML front matter for metadata when appropriate"
    "Only write markdown that adds value beyond improving existing code naming and structure."
  ];
  formatter = {
    package = pkgs.dprint;
    args = [
      "fmt"
      "--stdin"
    ];
  };
  servers.typos-lsp = typosServer;
  additionalPackages = [
    pkgs.zola
    pkgs.presenterm
  ];
}
