{
  pkgs,
  typosServer,
  astGrepServer,
}:

{
  scope = "source.typst";
  extensions = [ "typ" ];
  instructions = [
    "For creating new sequence diagrams about complex interactions over time, see examples of diagrams of the typst Chronos library in https://git.kb28.ch/HEL/chronos/src/branch/main/gallery"
    "For node and edge based diagrams, see the examples of the Fletcher library in https://github.com/Jollywatt/typst-fletcher/tree/main/docs/gallery and use the minimal amount of styling necessary to convey an idea."
    "New functions should take named and optional parameters where possible."
    "Search on https://typst.app/universe/ whether someone else created a library for a common layout problem."
  ];
  formatter.package = pkgs.typstyle;
  servers = {
    tinymist = {
      package = pkgs.tinymist;
      config.preview.background = {
        exportPdf = "onType";
        enabled = true;
        args = [
          "--data-plane-host=127.0.0.1:23635"
          "--open"
          "--invert-colors=auto"
        ];
      };
    };
    typos-lsp = typosServer;
    ast-grep-lsp = astGrepServer;
  };
  compiler.package = pkgs.typst;
}
