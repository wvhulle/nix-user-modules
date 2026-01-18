{
  pkgs,
  harper-ls,
}:

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
      "markdown"
    ];
  };
  servers = {
    inherit harper-ls;
    # typos-lsp = typosServer;
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
