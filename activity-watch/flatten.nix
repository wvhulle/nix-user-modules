{ lib }:

categories:
let
  processCategory =
    path: name: value: depth: index:
    let
      currentPath = path ++ [ name ];
      categoryId = depth * 1000 + index;

      currentCategory = {
        id = categoryId;
        name = currentPath;
        name_pretty = lib.concatStringsSep " > " currentPath;
        subname = name;
        inherit depth;
        parent = if path == [ ] then null else path;
        rule =
          if (value.regex or null) != null then
            {
              type = "regex";
              inherit (value) regex;
              ignore_case = value.ignore_case or false;
            }
          else if (value.keywords or null) != null then
            {
              type = "regex";
              regex = lib.concatStringsSep "|" value.keywords;
              ignore_case = value.ignore_case or false;
            }
          else
            {
              type = "none";
            };
        data =
          { }
          // lib.optionalAttrs ((value.color or null) != null) { inherit (value) color; }
          // lib.optionalAttrs ((value.score or null) != null) { inherit (value) score; };
      };

      childCategories =
        if (value.children or null) != null then
          lib.flatten (
            lib.imap0
              (
                childIndex: childEntry:
                let
                  childName = childEntry.name;
                  childValue = childEntry.value;
                in
                processCategory currentPath childName childValue (depth + 1) childIndex
              )
              (
                lib.mapAttrsToList (n: v: {
                  name = n;
                  value = v;
                }) value.children
              )
          )
        else
          [ ];
    in
    [ currentCategory ] ++ childCategories;
in
lib.flatten (
  lib.imap0
    (
      index: entry:
      let
        inherit (entry) name;
        inherit (entry) value;
      in
      processCategory [ ] name value 0 index
    )
    (
      lib.mapAttrsToList (n: v: {
        name = n;
        value = v;
      }) categories
    )
)
