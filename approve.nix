{
  terminalCommands = {
    git-read = {
      autoApprove = true;
      exactCommands = [
        "git status"
        "git log"
        "git diff"
        "git show"
        "git branch"
        "git remote"
      ];
      regexPatterns = [ ];
    };

    nix-read = {
      autoApprove = true;
      exactCommands = [
        "nix-prefetch-url"
        "nix-store --verify"
        "nix-env --query"
        "nix-instantiate"
      ];
      regexPatterns = [
        "/^nixos-rebuild (dry-run|dry-build)\\b/"
        "/^nix (search|show-config|show-derivation|eval|flake)\\b/"
      ];
    };

    nix-write = {
      autoApprove = true;
      exactCommands = [ ];
      regexPatterns = [
        "/^sudo nixos-rebuild (switch|test|boot)\\b/"
      ];
    };

    system-info = {
      autoApprove = true;
      exactCommands = [
        "ps"
        "top"
        "htop"
        "free"
        "uname"
        "whoami"
        "id"
        "date"
        "uptime"
        "nft list ruleset"
        "bluetoothctl devices"
        "find"
      ];
      regexPatterns = [
        "/^systemctl\\s+(status|list-units|--failed|show)\\b/"
        "/^journalctl\\b/"
      ];
    };

    file-read = {
      autoApprove = true;
      exactCommands = [
        "pwd"
        "which"
        "whereis"
        "tree"
      ];
      regexPatterns = [
        "/^ls\\b/"
        "/^cat\\b/"
        "/^head\\b/"
        "/^tail\\b/"
        "/^grep\\b/"
        "/^find\\b/"
        "/^du\\b/"
        "/^df\\b/"
        "/^wc\\b/"
        "/^file\\b/"
      ];
    };

    development = {
      autoApprove = true;
      exactCommands = [
        "make"
        "npm test"
        "npm run test"
        "pytest"
        "go test"
        "mvn test"
        "gradle test"
      ];
      regexPatterns = [
        "/^cargo\\s+(test|build|check|clippy|fmt|doc|run)\\b/"
        "/^npm\\s+(test|run\\s+test|run\\s+build|install|ci)\\b/"
        "/^(python|python3)\\s+-m\\s+pytest\\b/"
        "/^go\\s+(build|test|run)\\b/"
      ];
    };

    network-safe = {
      autoApprove = true;
      exactCommands = [ "ping" ];
      regexPatterns = [
        "/^curl\\s+(--head|-I|--silent|-s)\\b/"
        "/^wget\\s+(--spider|-S)\\b/"
      ];
    };

    dangerous = {
      autoApprove = false;
      exactCommands = [
        "dd"
        "mkfs"
        "fdisk"
        "parted"
        "reboot"
        "shutdown"
        "poweroff"
      ];
      regexPatterns = [
        "/rm\\s+.*-rf?\\s+/"
        "/rm\\s+-[^\\s]*r[^\\s]*f/"
        "/dangerous/"
        "/\\.(sh|bash|ps1)$/"
        "/\\|\\s*sh\\b/"
        "/\\|\\s*bash\\b/"
      ];
    };
  };
}
