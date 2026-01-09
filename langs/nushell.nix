{ pkgs, typosServer }:

{
  scope = "source.nu";
  extensions = [ "nu" ];
  instructions = [
    "Leverage Nushell's structured data capabilities for data manipulation."
    "Run nu-lint to see style issues in Nu scripts."
  ];
  formatter = {
    package = pkgs.topiary;
    args = [
      "format"
      "--language"
      "nu"
    ];
  };
  linter.package = pkgs.nu-lint;
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
      package = pkgs.nu-lint;
      args = [ "--lsp" ];
    };
    inherit typosServer;
  };
  additionalPackages = [ pkgs.nu-lint ];
}
