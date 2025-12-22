# Source: https://github.com/ast-grep/ast-grep-mcp
{
  lib,
  fetchFromGitHub,
  python3Packages,
  ast-grep,
}:

let
  version = "0.1.0";
  rev = "93d0320eff76d01240129a5c3cfa850c1d3a5e78";
in
python3Packages.buildPythonApplication {
  pname = "ast-grep-mcp";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ast-grep";
    repo = "ast-grep-mcp";
    inherit rev;
    hash = "sha256-RYu5vByPHrNMudPhaAyeYvXvFQUsGoJ3bWEDSFLHt78=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    mcp
    pyyaml
    pydantic
  ];

  postPatch = ''
    cat > pyproject.toml << EOF
    [project]
    name = "sg-mcp"
    version = "${version}"
    description = "ast-grep MCP server"
    requires-python = ">=3.11"
    dependencies = ["pydantic>=2.11.0", "mcp>=1.6.0", "pyyaml>=6.0.2"]

    [project.scripts]
    ast-grep-server = "main:run_mcp_server"

    [build-system]
    requires = ["hatchling"]
    build-backend = "hatchling.build"

    [tool.hatch.build.targets.wheel]
    packages = ["."]
    EOF
  '';

  nativeCheckInputs = with python3Packages; [
    pytest
    pytest-mock
  ];

  preCheck = ''
    export PATH="${lib.getBin ast-grep}/bin:$PATH"
  '';

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${lib.getBin ast-grep}/bin"
  ];

  pythonImportsCheck = [ ];

  meta = {
    description = "MCP server for ast-grep structural code search";
    homepage = "https://github.com/ast-grep/ast-grep-mcp";
    changelog = "https://github.com/ast-grep/ast-grep-mcp/commits/${rev}";
    license = lib.licenses.mit;
    mainProgram = "ast-grep-server";
  };
}
