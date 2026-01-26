{ pkgs, harper-ls }:

{
  scope = "source.nu";
  extensions = [ "nu" ];
  instructions = [
    "Leverage Nushell's structured data capabilities for data manipulation."
    "Run nu-lint to see style issues in Nu scripts."
  ];
  formatter = {
    package = pkgs.nufmt;
    args = [ "--stdin" ];
  };
  # Alternative: topiary formatter
  # formatter = {
  #   package = pkgs.topiary;
  #   args = [
  #     "format"
  #     "--language"
  #     "nu"
  #   ];
  # };
  servers = {
    nu = {
      package = pkgs.nushell;
      command = "nu";
      args = [
        "--lsp"
        "--no-config-file"
      ];
    };
    nu-lint = {
      command = "nu-lint";
      args = [ "--lsp" ];
    };
    inherit harper-ls;
  };
}
