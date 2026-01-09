{
  lib,
  pkgs,
  typosServer,
  astGrepServer,
}:

let
  myFlake = ''(builtins.getFlake "/etc/nixos")'';
  hostName = "ryzen";
  nixosOpts = "${myFlake}.nixosConfigurations.${hostName}.options";
in
{
  scope = "source.nix";
  extensions = [ "nix" ];
  instructions = [ ];

  terminalCommands = {
    nix-read = {
      autoApprove = true;
      exactCommands = [
        "nix-prefetch-url"
        "nix-store --verify"
        "nix-env --query"
        "nix-instantiate"
      ];
      regexPatterns = [
        "/^nixos-rebuild (dry-run|dry-build)\\b/"
        "/^nix (search|show-config|show-derivation|eval|flake)\\b/"
      ];
    };
    nix-write = {
      autoApprove = true;
      exactCommands = [ ];
      regexPatterns = [ "/^sudo nixos-rebuild (switch|test|boot)\\b/" ];
    };
  };

  formatter.package = pkgs.nixfmt-rfc-style;

  servers = {
    nixd = {
      package = pkgs.nixd;
      command = "nixd";
      args = [ "--semantic-tokens=true" ];
      config.nixd = {
        nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
        formatting.command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
        options = {
          nixos.expr = nixosOpts;
          home-manager.expr = "${nixosOpts}.home-manager.users.type.getSubOptions []";
        };
      };
    };

    nil.package = pkgs.nil;
    typos-lsp = typosServer;
    ast-grep-lsp = astGrepServer;
  };

  additionalPackages = [ pkgs.nixpkgs-fmt ];
}
