# Aspect:    den.aspects.macos.tower
# Platforms: darwin, home-manager (macOS only; does nothing on Linux)
# Purpose:   Tower, the Git client, as a Homebrew cask, plus Dracula themes for
#            it: the free Dracula always, and Dracula PRO's variants for users
#            with magnanix.draculaPro. Tower uses Dracula PRO (or Dracula
#            without it) in dark mode, and Dracula PRO Alucard in light mode.
#
# Notes:
# - Tower isn't in nixpkgs. The cask updates itself (auto_updates), and the
#   license comes from git-tower.com.
# - Tower reads themes from ~/Library/Application Support/com.fournova.Tower3/Themes.
#   Each theme is a JSON .towertheme file, and Tower picks one by its `name`.
#   All themes here share one layout (`mkTheme`), which maps Dracula's color
#   roles onto Tower's fields as the Dracula spec does
#   (https://draculatheme.com/spec).
# - Dracula is linked into that folder from the Nix store, read-only.
# - Dracula PRO is licensed (see modules/den/dracula-pro.nix), so its colors
#   never enter this repo or the Nix store. Activation reads them from the
#   checkout's design/palette.md and writes each variant into Tower's Themes
#   folder. Before the checkout exists the PRO themes are skipped with a
#   warning; Tower then shows its default theme until the next switch.
# - Edit themes here, not in Tower's theme editor: the Dracula file is
#   read-only, and the PRO files are rewritten whenever they differ.
# - GTUserDefaultsDarkTheme and GTUserDefaultsLightTheme pick the themes for
#   dark and light mode. Without Dracula PRO there is no free light Dracula, so
#   light mode keeps whatever is chosen in Tower's settings. Quit Tower before
#   switching, or it may overwrite the settings with the values it already has
#   in memory.
# - The font is JetBrains Mono Nerd Font Mono, from den.aspects.fonts. Tower
#   falls back to its default font if that isn't installed.
let
  themesDir = "Library/Application Support/com.fournova.Tower3/Themes";

  # Free Dracula palette, by the role names Dracula PRO's palette.md uses.
  dracula = {
    Background = "282A36";
    Selection = "44475A";
    Foreground = "F8F8F2";
    Comment = "6272A4";
    Cyan = "8BE9FD";
    Green = "50FA7B";
    Orange = "FFB86C";
    Pink = "FF79C6";
    Purple = "BD93F9";
    Red = "FF5555";
    Yellow = "F1FA8C";
  };

  # A Tower theme (format version 6, the fields Tower's own themes use). `c`
  # maps role names to hex values; for Dracula PRO it maps each role to its
  # own name, and activation substitutes the real values.
  mkTheme =
    {
      name,
      c,
    }:
    let
      color = hexValue: alpha: {
        version = 3;
        inherit hexValue alpha;
      };
      solid = hex: color hex 1;
    in
    {
      version = 6;
      inherit name;
      # Stable per name, so Tower sees the same theme on every switch.
      identifier =
        let
          h = builtins.hashString "md5" "magnanix-tower-${name}";
          s = start: len: builtins.substring start len h;
        in
        "${s 0 8}-${s 8 4}-${s 12 4}-${s 16 4}-${s 20 12}";
      font = {
        name = "JetBrainsMonoNFM-Regular";
        size = 12;
      };

      # Text and background
      backgroundColor = solid c.Background;
      textColor = solid c.Foreground;
      selectedTextBackgroundColor = solid c.Selection;
      invisibleCharacterColor = color c.Comment 0.5;

      # Diff highlights. Tower draws these over the background, so they stay faint.
      addedColor = color c.Green 0.15;
      deletedColor = color c.Red 0.15;

      # Code: keywords pink, strings yellow, numbers purple, functions green,
      # types and identifiers cyan.
      commentColor = solid c.Comment;
      keywordColor = solid c.Pink;
      stringColor = solid c.Yellow;
      numberColor = solid c.Purple;
      symbolColor = solid c.Purple;
      functionColor = solid c.Green;
      identifierColor = solid c.Cyan;
      delimiterColor = solid c.Foreground;
      preprocessorStatementColor = solid c.Pink;
      urlColor = solid c.Cyan;

      # Markup (HTML, XML, CSS)
      xmlTagColor = solid c.Pink;
      attributeNameColor = solid c.Green;
      attributeValueColor = solid c.Yellow;
      cssSelectorColor = solid c.Green;

      # Markdown
      headingColor = solid c.Purple;
      emphasizedColor = solid c.Yellow;
      stronglyEmphasizedColor = solid c.Orange;
      codeBlockColor = solid c.Green;
    };

  # Dracula PRO variants: Tower theme name -> section of design/palette.md.
  # Each section's colors are layered over "Base Dracula PRO"'s.
  draculaProVariants = {
    "Dracula PRO" = "Dracula PRO";
    "Dracula PRO Alucard" = "Alucard";
    "Dracula PRO Blade" = "Dracula PRO - Blade";
    "Dracula PRO Buffy" = "Dracula PRO - Buffy";
    "Dracula PRO Lincoln" = "Dracula PRO - Lincoln";
    "Dracula PRO Morbius" = "Dracula PRO - Morbius";
    "Dracula PRO Nosferatu" = "Dracula PRO - Nosferatu";
    "Dracula PRO Van Helsing" = "Dracula PRO - Van Helsing";
  };
in
{
  den.aspects.macos.tower = {
    darwin.homebrew.casks = [ "tower" ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        draculaPro = config.magnanix.draculaPro;
        palette = "${draculaPro.dir}/design/palette.md";
        themesPath = "${config.home.homeDirectory}/${themesDir}";

        roles = lib.genAttrs (builtins.attrNames dracula) lib.id;

        # Templates for the PRO themes: role names where the colors go.
        proTemplates = (pkgs.formats.json { }).generate "tower-dracula-pro-templates" (
          lib.mapAttrs (name: section: {
            inherit section;
            theme = mkTheme {
              inherit name;
              c = roles;
            };
          }) draculaProVariants
        );

        writeProThemes = pkgs.writeShellScript "tower-dracula-pro-themes" ''
          set -euo pipefail
          export PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.gawk
              pkgs.jq
            ]
          }
          palette="$1"
          dir="$2"

          # palette.md's first part holds one table per variant:
          # | Role | `#HEX` | ... ; the terminal tables after it are ignored.
          colors="$(awk -F'|' '
            /^# Color Palette - Terminal/ { exit }
            /^## / { section = substr($0, 4); next }
            $3 ~ /`#[0-9A-Fa-f]{6}`/ {
              role = $2; gsub(/ /, "", role)
              hex = $3; gsub(/[ `#]/, "", hex)
              print section "\t" role "\t" toupper(hex)
            }' "$palette" \
            | jq -Rn 'reduce (inputs | split("\t")) as [$s, $r, $h] ({}; .[$s][$r] = $h)')"

          mkdir -p "$dir"
          jq -r 'keys[]' ${proTemplates} | while IFS= read -r name; do
            if ! theme="$(jq -e --arg name "$name" --argjson colors "$colors" '
                .[$name] as $t
                | ($colors["Base Dracula PRO"] + $colors[$t.section]) as $c
                | $t.theme
                | walk(if type == "object" and has("hexValue")
                       then .hexValue = ($c[.hexValue] // error("missing color " + .hexValue))
                       else . end)' ${proTemplates})"; then
              echo "Skipping Tower theme $name: $palette lacks some of its colors." >&2
              continue
            fi
            file="$dir/$name.towertheme"
            # Rewrite only on change, so Tower doesn't see a new file every switch.
            if [[ ! -f "$file" ]] || [[ "$(jq -cS . "$file" 2>/dev/null)" != "$(jq -cS . <<<"$theme")" ]]; then
              printf '%s\n' "$theme" > "$file"
            fi
          done
        '';
      in
      lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.file."${themesDir}/Dracula.towertheme".text = builtins.toJSON (mkTheme {
          name = "Dracula";
          c = dracula;
        });

        targets.darwin.defaults."com.fournova.Tower3" = {
          GTUserDefaultsDarkTheme = if draculaPro.enable then "Dracula PRO" else "Dracula";
        }
        // lib.optionalAttrs draculaPro.enable {
          GTUserDefaultsLightTheme = "Dracula PRO Alucard";
        };

        # Lets modules/den/dracula-pro.nix clone the checkout on this host.
        magnanix.draculaPro.usedBy = lib.mkIf draculaPro.enable [ "tower" ];

        # After the clone, so a fresh host gets the themes on its first switch.
        home.activation.towerDraculaPro = lib.mkIf draculaPro.enable (
          lib.hm.dag.entryAfter [ "writeBoundary" "draculaProClone" ] ''
            if [[ ! -f ${lib.escapeShellArg palette} ]]; then
              warnEcho ${lib.escapeShellArg "Skipping Tower's Dracula PRO themes: ${palette} is missing. Clone Dracula PRO to ${draculaPro.dir} and switch again."}
            elif [[ -v DRY_RUN ]]; then
              echo ${lib.escapeShellArg "Would write Tower's Dracula PRO themes to ${themesPath}"}
            else
              run ${writeProThemes} ${
                lib.escapeShellArgs [
                  palette
                  themesPath
                ]
              }
            fi
          ''
        );
      };
  };
}
