{ pkgs }:

{
  scope = "source.zig";
  extensions = [ "zig" ];
  additionalPackages = [ pkgs.zvm ];
}
