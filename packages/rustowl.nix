{
  lib,
  fetchFromGitHub,
  rustPlatform,
  curl,
  openssl,
  pkg-config,
  llvmPackages_19,
  zlib,
  libxml2,
}:

rustPlatform.buildRustPackage rec {
  pname = "rustowl";
  version = "0.3.4";

  src = fetchFromGitHub {
    owner = "cordx56";
    repo = "rustowl";
    rev = "v${version}";
    hash = "sha256-pCeVLTiZk2Pv00AK2JlZ1kHrOX1V9iGNaJCdx7hIL+8=";
  };

  cargoHash = "sha256-Y8ZBwW2UKp0lVJm54vs9Ll9rEJcNqrEBE5pWH1nTjrM=";

  nativeBuildInputs = [
    pkg-config
    curl
    llvmPackages_19.llvm
  ];

  buildInputs = [
    openssl
    llvmPackages_19.libllvm
    zlib
    libxml2
  ];

  env = {
    RUSTC_BOOTSTRAP = "1";
    RUSTUP_TOOLCHAIN = "1.89.0";
    LLVM_CONFIG = "${llvmPackages_19.llvm.dev}/bin/llvm-config";
  };

  preBuild = ''
    export NIX_LDFLAGS="$NIX_LDFLAGS -L${llvmPackages_19.libllvm}/lib"
  '';

  postInstall = ''
    mkdir -p $out/opt/rustowl
  '';

  meta = with lib; {
    description = "Visualize ownership and lifetimes in Rust for debugging and optimization";
    homepage = "https://github.com/cordx56/rustowl";
    license = licenses.mpl20;
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
