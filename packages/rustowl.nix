{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  rustc,
  autoPatchelfHook,
  makeWrapper,
  patchelf,
  pkg-config,
  zlib,
  llvmPackages_19,
}:

let
  version = "0.3.4";

in
rustPlatform.buildRustPackage rec {
  pname = "rustowl";
  inherit version;

  src = fetchFromGitHub {
    owner = "cordx56";
    repo = "rustowl";
    rev = "v${version}";
    hash = "sha256-pCeVLTiZk2Pv00AK2JlZ1kHrOX1V9iGNaJCdx7hIL+8=";
  };

  patches = [ ./rustowl-nix.patch ];

  cargoHash = "sha256-Y8ZBwW2UKp0lVJm54vs9Ll9rEJcNqrEBE5pWH1nTjrM=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    patchelf
    llvmPackages_19.llvm
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = [
    zlib
    llvmPackages_19.libllvm
    rustc.unwrapped
  ]
  ++ lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
  ];

  # Tell autoPatchelfHook to skip rustowlc - we handle librustc_driver via LD_LIBRARY_PATH
  autoPatchelfIgnoreMissingDeps = [ "librustc_driver-*.so" ];

  env = {
    RUSTC_BOOTSTRAP = "1";
    # build.rs reads this to extract the RUSTC_DRIVER_NAME
    RUSTUP_TOOLCHAIN = "stable";
    LLVM_CONFIG = "${llvmPackages_19.llvm.dev}/bin/llvm-config";
  };

  preBuild = ''
    export NIX_LDFLAGS="$NIX_LDFLAGS -L${llvmPackages_19.libllvm}/lib"
  '';

  postInstall = ''
    # Use nixpkgs rustc sysroot - it matches the rustc used to compile rustowlc
    sysroot="${rustc.unwrapped}"

    # Create wrapper scripts that set up the environment
    # RUSTOWL_SYSROOTS tells rustowl to use the nixpkgs rustc sysroot
    # LD_LIBRARY_PATH provides librustc_driver for rustowlc
    wrapProgram $out/bin/rustowl \
      --set RUSTOWL_SYSROOTS "$sysroot" \
      --prefix LD_LIBRARY_PATH : "${rustc.unwrapped}/lib"

    wrapProgram $out/bin/rustowlc \
      --prefix LD_LIBRARY_PATH : "${rustc.unwrapped}/lib"
  '';

  meta = with lib; {
    description = "Visualize ownership and lifetimes in Rust for debugging and optimization";
    homepage = "https://github.com/cordx56/rustowl";
    license = licenses.mpl20;
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
