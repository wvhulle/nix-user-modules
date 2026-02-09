{
  description = "Custom home-manager modules for declarative user configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = _: {
    homeManagerModules = {
      default = ./default.nix;
      activity-watch = ./activity-watch;
      direnv-extended = ./direnv-extended.nix;
      firefox-extended = ./firefox-extended.nix;
      git-extended = ./git-extended.nix;
      helix-extended = ./helix-extended.nix;
      keyboard-action = ./keyboard-action.nix;
      langs = ./langs;
      nushell-extended = ./nushell;
      topiary = ./topiary.nix;
      typos = ./typos.nix;
      stylix-extended = ./stylix.nix;
      vscode-extended = ./vscode-extended.nix;
      xdg-autostart-extended = ./xdg-autostart-extended.nix;
    };
  };
}
