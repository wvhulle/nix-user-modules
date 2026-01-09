{ pkgs, typosServer }:

{
  scope = "source.markdown";
  extensions = [
    "md"
    "markdown"
  ];
  instructions = [ ];
  formatter = {
    package = pkgs.dprint;
    args = [
      "fmt"
      "--stdin"
    ];
  };
  servers = {
    typos-lsp = typosServer;
    # marksman = {
    #   package = pkgs.marksman;
    # };
  };
  additionalPackages = [
    pkgs.zola
    pkgs.presenterm
    pkgs.markdown-oxide
  ];
}
