{
  config,
  lib,
  ...
}:

let
  cfg = config.xdg.autostart-extended;

  mkAutostartApps = packages: {
    xdg.configFile = lib.listToAttrs (
      map (pkg: {
        name = "autostart/${pkg.pname or pkg.name}.desktop";
        value = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=${pkg.meta.description or (pkg.pname or pkg.name)}
            Exec=${pkg}/bin/${pkg.pname or pkg.name}
            Terminal=false
            X-GNOME-Autostart-enabled=true
            X-KDE-autostart-after=panel
          '';
        };
      }) packages
    );
  };
in
{
  options.xdg.autostart-extended = {
    enable = lib.mkEnableOption "extended XDG autostart configuration";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages to automatically start on login";
      example = lib.literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
    };

    customEntries = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Custom autostart desktop entries";
      example = lib.literalExpression ''
        {
          "my-script" = {
            name = "My Custom Script";
            exec = "/path/to/script.sh";
            description = "Custom startup script";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = lib.mkMerge [
      (lib.mkIf (cfg.packages != [ ]) (mkAutostartApps cfg.packages).xdg.configFile)

      (lib.mapAttrs' (
        name: entry:
        lib.nameValuePair "autostart/${name}.desktop" {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=${entry.name or name}
            Exec=${entry.exec}
            Terminal=${if entry.terminal or false then "true" else "false"}
            X-GNOME-Autostart-enabled=true
            X-KDE-autostart-after=panel
            ${lib.optionalString (entry ? description) "Comment=${entry.description}"}
            ${lib.optionalString (entry ? icon) "Icon=${entry.icon}"}
          '';
        }
      ) cfg.customEntries)
    ];
  };
}
