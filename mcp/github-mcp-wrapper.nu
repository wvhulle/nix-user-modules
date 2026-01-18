#!/usr/bin/env nu

# Wrapper script for GitHub MCP server
# Sets GITHUB_PERSONAL_ACCESS_TOKEN from gh CLI auth
def main [
  github_mcp_bin: string # Path to github-mcp-server binary
] {
  let token = (gh auth token | str trim)

  if ($token | is-empty) {
    print -e "Error: Could not get GitHub token. Run 'gh auth login' first."
    exit 1
  }

  with-env {GITHUB_PERSONAL_ACCESS_TOKEN: $token} {
    ^$github_mcp_bin stdio
  }
}
