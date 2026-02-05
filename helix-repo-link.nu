#!/usr/bin/env nu

# Wraps base64-encoded data in OSC 52 escape sequence for clipboard
def osc52_clipboard_sequence [data: string]: nothing -> string {
  $"\e]52;;($data)\a"
}

# Parse remote URL to extract owner/repo
def parse_remote [url: string]: nothing -> record<host: string, owner: string, repo: string> {
  # Handle SSH format: git@github.com:owner/repo.git
  # Handle HTTPS format: https://github.com/owner/repo.git
  let cleaned = $url | str replace '.git' '' | str replace 'git@' '' | str replace ':' '/'
  let parts = $cleaned | parse --regex '(?<host>github\.com|codeberg\.org)/(?<owner>[^/]+)/(?<repo>.+)'
  $parts | first
}

def main [filename: string line: int] {
  let abs_path = $filename | path expand
  let git_root = do { cd ($abs_path | path dirname); ^git rev-parse --show-toplevel } | str trim
  let remote_url = do { cd $git_root; ^git remote get-url origin } | str trim
  let branch = do { cd $git_root; ^git rev-parse --abbrev-ref HEAD } | str trim
  let rel_path = $abs_path | path relative-to $git_root

  let remote = parse_remote $remote_url

  let link = match $remote.host {
    "github.com" => $"https://github.com/($remote.owner)/($remote.repo)/blob/($branch)/($rel_path)#L($line)"
    "codeberg.org" => $"https://codeberg.org/($remote.owner)/($remote.repo)/blame/branch/($branch)/($rel_path)#L($line)"
    _ => { error make {msg: $"Unsupported remote: ($remote.host)"} }
  }

  # Print the link first (for :echo %sh{} to capture)
  print $link

  # Copy to clipboard via OSC 52 (may fail outside terminal)
  let encoded = $link | encode base64
  try { osc52_clipboard_sequence $encoded | save --force /dev/tty }
}
