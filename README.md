# Home Manager Modules

This repository defines a set of configuration modules that can be used to manage common Linux desktop applications and tools declaratively. I use most of the modules in this repository on a daily basis and fix bugs whenever I encounter them.

You need to have [home-manager](https://github.com/nix-community/home-manager) installed.

## Usage

Add to your flake inputs:

```nix
inputs.user-modules.url = "github:wvhulle/nix-user-modules";
```

Import specific modules:

```nix
imports = [ inputs.user-modules.homeManagerModules.vscode-extended ];

programs.vscode-extended.enable = true;
```

Or import all modules:

```nix
imports = [ inputs.user-modules.homeManagerModules.default ];
```

See [Nix flakes](https://nixos.wiki/wiki/Flakes) and [home-manager](https://nix-community.github.io/home-manager) documentation.
