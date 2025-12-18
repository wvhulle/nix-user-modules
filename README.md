# User Modules

The [home-manager](https://github.com/nix-community/home-manager) project allows Linux (but also Mac) users to declare application-specific configuration using [Nix](https://github.com/nix-community), a language (and ecosystem) that extends JSON with functions.

The files in this directory are custom [home-manager](https://github.com/nix-community/home-manager) modules for declarative user configuration.

## Usage

To use these custom user modules in your NixOS configuration, import them directly from the GitHub repository:

```nix
{ config, pkgs, ... }:
{
    imports = [
        (builtins.fetchGit {
            url = "https://github.com/wvhulle/nix-user-modules.git";
            rev = "main";
        } + "/vscode-extended.nix")
    ];

    programs.vscode-extended.enable = true;
}
```

Or use `fetchTarball` for a more stable approach:

```nix
{ config, pkgs, ... }:
let
    userModules = builtins.fetchTarball {
        url = "https://github.com/wvhulle/nix-user-modules/archive/main.tar.gz";
    };
in
{
    imports = [
        "${userModules}/vscode-extended.nix"
    ];

    programs.vscode-extended.enable = true;
}
```

Then run `home-manager switch` to write settings declaratively to your home directory.

(All files will be symlinks to read-only paths in the Nix store, except for VS Code settings.)
