{
  pkgs,
  ...
}:

{
  # GNOME Keyring without SSH component (using Bitwarden SSH agent)
  services.gnome-keyring = {
    enable = true;
    components = [
      "secrets"
      "pkcs11"
    ];
  };

  services.gpg-agent = {
    enable = true;
    enableNushellIntegration = true;
    enableBashIntegration = true;
    defaultCacheTtl = 3600; # 1 hour
    maxCacheTtl = 86400; # 24 hours
    pinentry.package = pkgs.pinentry-qt;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      extraOptions = {
        IdentityAgent = "~/.bitwarden-ssh-agent.sock";
      };
    };
  };

  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
  };
}
