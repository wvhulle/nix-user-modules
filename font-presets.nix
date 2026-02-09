{ pkgs }:

{
  plex = {
    monospace = {
      package = pkgs.nerd-fonts.blex-mono;
      name = "BlexMono Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Sans";
    };
    serif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Serif";
    };
  };

  fira = {
    monospace = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.fira;
      name = "Fira Sans";
    };
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
  };

  jetbrains = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
  };

  hack = {
    monospace = {
      package = pkgs.nerd-fonts.hack;
      name = "Hack Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.roboto;
      name = "Roboto";
    };
    serif = {
      package = pkgs.roboto-slab;
      name = "Roboto Slab";
    };
  };

  iosevka = {
    monospace = {
      package = pkgs.nerd-fonts.iosevka;
      name = "Iosevka Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.iosevka;
      name = "Iosevka Aile";
    };
    serif = {
      package = pkgs.iosevka;
      name = "Iosevka Etoile";
    };
  };

  lilex = {
    monospace = {
      package = pkgs.lilex;
      name = "Lilex Medium";
    };
    sansSerif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Sans";
    };
    serif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Serif";
    };
  };

  monaspace = {
    monospace = {
      package = pkgs.nerd-fonts.monaspace;
      name = "Monaspace Neon";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
  };

  cascadia = {
    monospace = {
      package = pkgs.nerd-fonts.caskaydia-cove;
      name = "CaskaydiaCove Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
  };

  sourcecodepro = {
    monospace = {
      package = pkgs.nerd-fonts.sauce-code-pro;
      name = "SauceCodePro Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.source-sans;
      name = "Source Sans 3";
    };
    serif = {
      package = pkgs.source-serif;
      name = "Source Serif 4";
    };
  };
}
