{
  lib,
  pkgs,
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
  mimeTypes = [ "text/x-nix" ];
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

  linter = {
    package = pkgs.deadnix;
    args = [ "--fail" ];
  };

  servers = {
    nixd = {
      package = pkgs.nixd;
      # command = "nixd";
      args = [
        "--inlay-hints"
        "--semantic-tokens=true"
        # "--log=verbose" # In case there are issues
      ];
      config.nixd = {
        nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
        formatting.command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
        options = {
          nixos.expr = nixosOpts;
          home-manager.expr = "${nixosOpts}.home-manager.users.type.getSubOptions []";
        };
      };
    };

    nil = {
      package = pkgs.nil;
      name = "nil_ls";
      config.nil = {
        diagnostics = {
          ignored = [ ]; # Empty = show all diagnostics (unused_binding, unused_with, etc.)
        };
        nix = {
          flake = {
            autoArchive = true;
            autoEvalInputs = true;
          };
        };
      };
    };

    ast-grep-lsp = astGrepServer;
  };

  additionalPackages = with pkgs; [
    nixpkgs-fmt
    statix
    shellify
    nix-init
    nix-tree
    nix-diff
    nix-prefetch-github
    nix-prefetch-git
    nixos-option
    home-manager
    nh
  ];
}
