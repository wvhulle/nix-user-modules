{ pkgs }:

let
  themesDir = "${pkgs.base16-schemes}/share/themes";
  themeFiles = builtins.readDir themesDir;
  themeNames = builtins.filter (name: builtins.match ".*\\.yaml" name != null) (
    builtins.attrNames themeFiles
  );
  stripExt = name: builtins.head (builtins.match "(.*)\\.yaml" name);
in
builtins.listToAttrs (
  map (file: {
    name = stripExt file;
    value = stripExt file;
  }) themeNames
)
