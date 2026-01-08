{ pkgs, astGrepServer }:

{
  scope = "source.python";
  extensions = [ "py" ];
  instructions = [
    "Use type hints"
    "Use structured error handling with specific exception types"
    "Validate inputs and provide clear error messages"
  ];
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
