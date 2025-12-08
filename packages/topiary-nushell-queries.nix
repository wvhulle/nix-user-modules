{ pkgs }:

let
  tree-sitter-nu-grammar = pkgs.tree-sitter.buildGrammar {
    language = "nu";
    version = "0.0.1";
    src = pkgs.fetchFromGitHub {
      owner = "nushell";
      repo = "tree-sitter-nu";
      rev = "18b7f951e0c511f854685dfcc9f6a34981101dd6";
      sha256 = "sha256-OSazwPrUD7kWz/oVeStnnXEJiDDmI7itiDPmg062Kl8=";
    };
  };

  topiary-queries-src = pkgs.fetchFromGitHub {
    owner = "blindFS";
    repo = "topiary-nushell";
    rev = "fd78be393af5a64e56b493f52e4a9ad1482c07f4";
    sha256 = "sha256-5gmLFnbHbQHnE+s1uAhFkUrhEvUWB/hg3/8HSYC9L14=";
  };

in
pkgs.stdenv.mkDerivation {
  pname = "topiary-nushell-queries";
  version = "0.1.0";

  src = topiary-queries-src;

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/queries

    # Copy query files from blindFS repo
    cp -r languages/* $out/queries/

    # Copy pre-compiled grammar
    cp ${tree-sitter-nu-grammar}/parser $out/queries/nu.so
  '';

  meta = with pkgs.lib; {
    description = "Tree-sitter grammar and queries for Nushell to use with Topiary";
    homepage = "https://github.com/blindFS/topiary-nushell";
    license = pkgs.lib.licenses.mit;
  };
}
