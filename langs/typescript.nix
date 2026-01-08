_:

{
  scope = "source.ts";
  extensions = [
    "ts"
    "tsx"
  ];
  instructions = [
    "Don't create separate types or types.ts modules or files, integrate definitions with related code."
    "For NodeJS projects, always add strict eslint lint configuration that enforces a modern idiomatic functional TypeScript style."
  ];
  enable = false;
}
