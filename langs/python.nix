{ pkgs, astGrepServer }:

{
  scope = "source.python";
  extensions = [ "py" ];
  instructions = [ "Use type hints" ];
  servers = {
    ast-grep-lsp = astGrepServer;
    ty = {
      package = pkgs.ty;
      command = "ty";
      args = [ "server" ];
    };
  };
  additionalPackages = [ pkgs.uv ];
}
