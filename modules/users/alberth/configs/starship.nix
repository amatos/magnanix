# User:      alberth (den.aspects.alberth.starship)
# Platforms: home-manager
# Purpose:   alberth's Starship prompt. Starship itself is enabled for every
#            user by den.aspects.shell.starship; this only adds the settings.
#
# Notes (changes from Starship's defaults):
# - A powerline-style head: OS icon (blue) → username, or user@host over
#   SSH (red) → directory (green), followed by git branch/status and
#   everything else via `$all`.
# - Emoji symbols for the OS, language and git modules; the powerline
#   separators still need a Nerd Font in the terminal.
# - The prompt character is λ (✗ after a failed command).
# - The prompt shows which shell you're in: 🐚 bash, 🦓 zsh, 🐟 fish,
#   🪟 PowerShell, ❓ anything else.
{
  den.aspects.alberth.starship = {
    homeManager =
      { lib, ... }:
      let
        versionFormat = "[$symbol($version)]($style)";

        # Modules that only set a symbol and the shared format.
        symbolModules =
          lib.mapAttrs
            (_: symbol: {
              inherit symbol;
              format = versionFormat;
            })
            {
              fossil_branch = " 🦴 ";
              aws = " ☁️ ";
              buf = " 🐃 ";
              c = " 🇨 ";
              cmake = " 🔺 ";
              conda = " 🅒 ";
              crystal = " 🔮 ";
              dart = " 🎯 ";
              docker_context = " 🐳 ";
              elixir = " 💧 ";
              elm = " 🌳 ";
              fennel = " 🧅 ";
              golang = " 🐹 ";
              guix_shell = " 🐃 ";
              haskell = " 🟣 ";
              haxe = " 🔶 ";
              hg_branch = " 🌿 ";
              java = " ☕ ";
              julia = " 🔵 ";
              kotlin = " 🅺 ";
              lua = " 🌙 ";
              memory_usage = " 🐏 ";
              meson = " 🔷 ";
              nim = " 👑 ";
              nix_shell = " ❄️ ";
              nodejs = " 🟢 ";
              ocaml = " 🐫 ";
              package = " 📦 ";
              perl = " 🐪 ";
              php = " 🐘 ";
              pijul_channel = " 🪶 ";
              python = " 🐍 ";
              rlang = " 📊 ";
              ruby = " 💎 ";
              rust = " 🦀 ";
              scala = " 🔴 ";
              swift = " 🐦 ";
              zig = " ⚡ ";
              gradle = " 🐘 ";
            };
      in
      {
        programs.starship.settings = symbolModules // {
          format = lib.concatStrings [
            "[](fg:blue)"
            "$os"
            "[](bg:blue fg:red)"
            "$username"
            "$hostname"
            "[ ](bg:red)"
            "[](bg:red fg:green)"
            "$directory"
            "[ ](fg:green)"
            "$git_branch"
            "$git_status"
            "$all"
            "$character"
          ];

          username = {
            show_always = true;
            format = "[$user](bg:red fg:black)";
            disabled = false;
          };

          os = {
            disabled = false;
            style = "bg:blue fg:black";
            symbols = {
              Alpaquita = "🦙 ";
              Alpine = "🏔️ ";
              AlmaLinux = "💠 ";
              Amazon = "🙂 ";
              Android = "🤖 ";
              Arch = "🎗️ ";
              Artix = "🎗️ ";
              CachyOS = "🎗️ ";
              CentOS = "💠 ";
              Debian = "🌀 ";
              DragonFly = "🐉 ";
              Emscripten = "🔗 ";
              EndeavourOS = "🚀 ";
              Fedora = "🎩 ";
              FreeBSD = "😈 ";
              Garuda = "🦅 ";
              Gentoo = "🗜️ ";
              HardenedBSD = "🛡️ ";
              Illumos = "🐦 ";
              Kali = "🐉 ";
              Linux = "🐧 ";
              Mabox = "📦 ";
              Macos = "🍎 ";
              Manjaro = "🥭 ";
              Mariner = "🌊 ";
              MidnightBSD = "🌘 ";
              Mint = "🌿 ";
              NetBSD = "🚩 ";
              NixOS = "❄️ ";
              Nobara = "🎩 ";
              OpenBSD = "🐡 ";
              openSUSE = "🦎 ";
              OracleLinux = "🦴 ";
              Pop = "🍭 ";
              Raspbian = "🍓 ";
              Redhat = "🎩 ";
              RedHatEnterprise = "🎩 ";
              RockyLinux = "🪨 ";
              Redox = "🧪 ";
              Solus = "⛵ ";
              SUSE = "🦎 ";
              Ubuntu = "🎯 ";
              Unknown = "❓ ";
              Void = "🌑 ";
              Windows = "🪟 ";
            };
          };

          shell = {
            bash_indicator = "🐚";
            zsh_indicator = "🦓";
            fish_indicator = "🐟";
            powershell_indicator = "🪟";
            unknown_indicator = "❓";
            style = "cyan bold";
            disabled = false;
          };

          cmd_duration.format = "[$duration](fg:red)";

          directory = {
            format = "[$path](bg:green fg:black)";
            truncation_length = 2;
            truncation_symbol = "…/";
            substitutions = {
              "Documents" = "📄 ";
              "Downloads" = "📥 ";
              "Music" = "🎵 ";
              "Pictures" = "🖼️ ";
              "Scripts" = "📜 ";
            };
          };

          character = {
            success_symbol = "[λ](bold blue)";
            error_symbol = "[✗](bold red)";
            disabled = false;
          };

          git_branch = {
            symbol = " 🌱 ";
            format = "[$symbol($branch) ($version)]($style)";
          };

          git_commit = {
            tag_symbol = " 🏷️ ";
            format = versionFormat;
          };

          # Only over SSH, so the red section reads user@host there and just
          # user locally. trim_at (default ".") drops the domain.
          hostname = {
            ssh_only = true;
            format = "[@$hostname](bg:red fg:black)";
          };
        };
      };
  };
}
