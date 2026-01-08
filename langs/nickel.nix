{ pkgs }:

{
  extensions = [ "ncl" ];
  scope = "source.nickel";
  fileTypes = [ "ncl" ];
  roots = [ ".git" ];
  servers.nls.package = pkgs.nls;
  additionalPackages = [ pkgs.nickel ];
}
