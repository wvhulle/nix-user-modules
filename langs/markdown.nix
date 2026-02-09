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
  mimeTypes = [
    "text/markdown"
    "text/x-markdown"
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
    mpls = {
      package = pkgs.mpls;
      command = "mpls";
      args = [
        "--enable-emoji"
      ];
    };

    marksman = {
      package = pkgs.marksman;
      command = "marksman";
    };
  };
  additionalPackages = with pkgs; [
    zola
    presenterm
    markdown-oxide
    mermaid-cli
    glow
  ];
}
