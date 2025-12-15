{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  stdenv,
  darwin,
}:

rustPlatform.buildRustPackage rec {
  pname = "tytanic";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "typst-community";
    repo = "tytanic";
    rev = "v${version}";
    hash = "sha256-7+t7M20QwTnZYEay7feDOBm0EeQM58lHVNAvFyNOMU8=";
  };

  cargoHash = "sha256-00NlKGyGeuti/BudjpPuMxRU0AY5TG8Zsfl4vaPJeFg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk.frameworks.CoreServices
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  # Tests require network access and a full typst environment
  doCheck = false;

  meta = {
    description = "A test runner for Typst projects";
    homepage = "https://typst-community.github.io/tytanic/";
    changelog = "https://github.com/typst-community/tytanic/blob/v${version}/docs/CHANGELOG.md";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = [ ];
    mainProgram = "tt";
  };
}
