{
  pkgs,
  harper-ls,
  astGrepServer,
}:

{
  scope = "source.typst";
  extensions = [ "typ" ];
  instructions = [
    "Sequence diagrams: Chronos library (https://git.kb28.ch/HEL/chronos)"
    "Node/edge diagrams: Fletcher library (https://github.com/Jollywatt/typst-fletcher)"
    "Search https://typst.app/universe/ for existing solutions"
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
    inherit harper-ls;
    ast-grep-lsp = astGrepServer;
  };
  compiler.package = pkgs.typst;
}
