# Default ActivityWatch categories
# Users can import this file or define their own categories

{
  Work = {
    regex = "Google Docs|libreoffice|ReText";
    color = "#2E7D32"; # Green base
    score = 10;
    children = {
      Programming = {
        keywords = [
          "software"
          "Git"
          "GitHub"
          "Stack Overflow"
          "BitBucket"
          "Gitlab"
          "vim"
          "Spyder"
          "kate"
          "Ghidra"
          "Scite"
          "Visual studio"
          "Konsole"
          "README\\.md"
          "Repositories"
          "pull request"
          "zellij"
          "Code"
          "Issue"
          "Programming"
          "Meld"
          "at main"
        ];
        color = "#1565C0"; # Deep blue for programming
        children = {
          ActivityWatch = {
            keywords = [
              "ActivityWatch"
              "aw-"
            ];
            color = "#4527A0"; # Deep purple
          };
          Lean = {
            keywords = [
              "Lean"
              "lake"
              "elan"
              "\\.lean"
              "lean"
              "lean4"
              "Reservoir"
              "ennreal"
            ];
            color = "#6A1B9A"; # Purple
          };
          Rust = {
            keywords = [
              "rust"
              "cargo"
              "\\.rs"
            ];
            color = "#D84315"; # Deep orange
          };
          Python = {
            keywords = [
              "python"
              "\\.py"
            ];
            color = "#F4511E"; # Orange
          };
          Web = {
            keywords = [
              "\\.html"
              "\\.css"
              "\\.js"
              "\\.ts"
            ];
            color = "#00838F"; # Teal
          };
          Zig = {
            keywords = [ "zig" ];
            color = "#FFA000"; # Amber
          };
          Nix = {
            keywords = [
              "\\.nix"
              "nixos"
              "nixpkgs"
              "home manager"
            ];
            color = "#5D4037"; # Brown
          };
          Shell = {
            keywords = [
              "nushell"
              "bash"
              "shell"
              "nu"
              "fish"
              "zsh"
              "konsole"
              "kitty"
              "alacritty"
              "terminal"
            ];
            color = "#424242"; # Dark grey
          };
        };
      };
      Image = {
        keywords = [
          "GIMP"
          "Inkscape"
        ];
        color = "#AD1457"; # Pink
      };
      Video = {
        keywords = [
          "Kdenlive"
          "OBS studio"
        ];
        color = "#6A1B9A"; # Purple
      };
      Audio = {
        keywords = [
          "Audacity"
          "mixxx"
        ];
        color = "#00695C"; # Teal
      };
      "3D" = {
        keywords = [ "Blender" ];
        color = "#FF6F00"; # Amber
      };
      Sysghent = {
        keywords = [
          "sysghent"
          "systems programming ghent"
          "Meetup"
          "SysGhent"
          "Mobilizon"
        ];
        color = "#3E2723"; # Dark brown
      };
      "Job hunting" = {
        keywords = [
          "linkedin"
          "malt"
          "jobs"
          "job"
          "companies"
          "company"
          "vacature"
          "vdab"
          "profile"
          "public profile"
          "volunteering"
          "skills"
          "beroep"
          "VDAB"
        ];
        color = "#37474F"; # Blue grey
      };
      Linux = {
        keywords = [
          "preferences"
          "Dolphin"
          "file explorer"
          "files"
          "houtlei\\.willemvanhulle\\.tech"
          "home assistant"
          "home-assistant"
          "homeassistant"
          "localhost"
          "Networking"
        ];
        color = "#455A64"; # Blue grey
      };
      Math = {
        keywords = [
          "Probability"
          "measure"
          "theory"
          "math"
          "mathematics"
          "algebra"
          "formula"
          "equation"
          "calc"
          "law of"
          "lemma"
          "theorem"
          "axiom"
        ];
        color = "#5E35B1"; # Deep purple
      };
    };
  };

  Media = {
    color = "#D32F2F"; # Red base
    keywords = [ "firefox" ];
    children = {
      Games = {
        keywords = [
          "Minecraft"
          "RimWorld"
          "Steam"
          "game"
        ];
        color = "#F44336"; # Lighter red
      };
      Video = {
        keywords = [
          "YouTube"
          "Plex"
          "VLC"
          "Sphinx"
          "trailer"
        ];
        color = "#E57373"; # Even lighter red
      };
      "Social Media" = {
        keywords = [
          "reddit"
          "Facebook"
          "Twitter"
          "Instagram"
          "devRant"
          "mastodon"
        ];
        color = "#EF5350";
      };
      Music = {
        keywords = [
          "Spotify"
          "Deezer"
          "muziek"
          "music"
          "Shortwave"
          "pitchfork"
          "Трекер"
          "RuTracker.org"
        ];
        color = "#FF5722"; # Red-orange
      };
      LLM = {
        regex = "gemini|Claude|opus|sonnet|anthropic|chatgpt|openai|\\.CLAUDE\\.md|claude|OpenRouter|ChatGPT|MCP|Anthropic|Gemini|LLM|ollama|hugging face|lmstudio|lm studio|open webui";
        color = "#FF6F00"; # Orange
      };
      Shopping = {
        keywords = [
          "Coolblue"
          "CAPS"
          "azerty"
          "Shipping"
          "Lenovo"
          "monitor"
          "Webshop"
          "Laptops"
          "koop"
          "kopen"
          "mediamarkt"
          "bol\\.com"
        ];
        color = "#FF8F00"; # Light orange
      };
      News = {
        keywords = [
          "CNN"
          "Nieuwsblad"
          "demorgen"
          "humo"
          "detijd"
          "vrt"
          "nieuws"
          "news"
          "News"
          "the atlantic"
          "world news"
          "nyt"
          "politic"
        ];
        color = "#FFA726"; # Lighter orange
      };
      Science = {
        keywords = [
          "Scientific"
          "Science"
          "Wikipedia"
          "wiki"
          "encyclopedia"
          "physics"
          "chemistry"
          "science"
          "educational"
          "experiment"
          "research"
          "arxiv"
          "publication"
          "pdf"
        ];
        color = "#FFAB91"; # Light orange-pink
      };
      Books = {
        keywords = [
          "Goodreads"
          "Library"
          "Books"
          "book"
        ];
        color = "#FFCC80"; # Very light orange
      };
    };
  };

  Comms = {
    color = "#1976D2"; # Blue base
    children = {
      Chat = {
        keywords = [
          "Messenger"
          "Telegram"
          "Signal"
          "WhatsApp"
          "Rambox"
          "Riot"
          "Discord"
          "Nheko"
          "NeoChat"
        ];
        color = "#2196F3"; # Lighter blue
      };
      Email = {
        keywords = [
          "Gmail"
          "Thunderbird"
          "mutt"
          "alpine"
          "Mail"
          "Protonmail"
          "mail\\.proton\\.me"
        ];
        color = "#42A5F5"; # Even lighter blue
      };
      Forums = {
        keywords = [
          "forum"
          "zulip"
          "disqus"
          "Mattermost"
          "slack"
          "discuss"
        ];
        color = "#64B5F6"; # Light blue
      };
      "Video meeting" = {
        keywords = [
          "calendar"
          "meeting"
          "zoom"
          "teams"
          "google-meet"
          "google meet"
        ];
        color = "#90CAF9"; # Very light blue
      };
    };
  };

  Uncategorized = {
    color = "#757575"; # Neutral grey
  };
}
