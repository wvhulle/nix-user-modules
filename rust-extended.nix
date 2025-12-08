{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.rust-extended;
  cargoPath = "${config.home.homeDirectory}/.cargo/bin";
in
{
  options.programs.rust-extended = {
    enable = lib.mkEnableOption "extended Rust/Cargo configuration";

    addCargoToPath = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add ~/.cargo/bin to PATH for all shells and desktop sessions";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add ~/.cargo/bin to PATH for non-nushell shells and desktop sessions
    home.sessionPath = lib.mkIf cfg.addCargoToPath [ cargoPath ];

    # Add ~/.cargo/bin to PATH for nushell specifically
    programs.nushell-extended.additionalPaths = lib.mkIf cfg.addCargoToPath [ cargoPath ];
  };
}
