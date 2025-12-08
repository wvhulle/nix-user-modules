# Nix-User-Modules

The [home-manager](https://github.com/nix-community/home-manager) project allows Linux (but also Mac) users to declare application-specific configuration using [Nix](https://github.com/nix-community), a language (and ecosystem) that extends JSON with functions.

The files in this repo are a snapshot of the custom [home-manager](https://github.com/nix-community/home-manager) modules I use on a daily basis.

To import a custom user module in your NixOS configuration:

1. Clone this project somewhere (or use Nix builtins)
2. Import and enable sub-modules in your NixOS configuration:

   ```nix
   { config, pkgs, ... }:
   {
       imports = [
           ./user-modules/vscode-extended.nix
       ];

       programs.vscode-extended.enable = true;
   }
   ```

Then run `sudo nixos-rebuild switch` (or a home-manager command) to write settings declaratively to your home directory.

(All files will be symlinks to read-only paths in the Nix store, except for VS Code settings.)

## Reminder

Update with:

```bash
git subtree push --prefix=user-modules git@github.com:wvhulle/nix-user-modules.git main
```

If it does not work:

```bash
git subtree split --prefix=user-modules -b temp-subtree
git push git@github.com:wvhulle/nix-user-modules.git temp-subtree:main --force
git branch -D temp-subtree
```
