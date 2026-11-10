# macOS

## macOS defaults

`modules/packages/darwin/` holds one aspect per System Settings area, under `den.aspects.darwin.*`:
`controlCenter`, `finder`, `loginWindow`, `menuExtraClock`, `nsGlobalDomain`, `screencapture`,
`screenSaver`, `softwareUpdate` and `trackpad`. Each sets `system.defaults.*` through the `darwin` class (and
`CustomUserPreferences` for keys nix-darwin has no option for). `darwin.nix` bundles them as
`den.aspects.darwin.customizations`, which `base` includes, so they apply to every macOS host.

- `den.aspects.alberth.macos.dock` (`modules/users/alberth/dock.nix`) is the exception: it follows alberth rather
  than applying to every macOS host, so hosts without alberth keep the default Dock.
- `dock` and `screencapture` build paths such as `/Users/<name>/Downloads` from `system.primaryUser`, which each
  host sets with `den.batteries.primary-user`.
- `screencapture` creates its target directory (`~/Pictures/Screenshots/unsorted`) in a `postActivation` script,
  because nix-darwin doesn't and macOS ignores a missing location.
- The Dock's `persistent-apps` list is declarative: manual Dock changes are overwritten on the next switch.
  Orion comes from Home Manager (`~/Applications/Home Manager Apps`); Helium, Zed, Delta and Claude are Homebrew
  casks; iTerm is installed by hand.
- New files must be tracked by git (`git add`) before a plain `.#` flake reference can see them.

### Keyboard repeat

`nsGlobalDomain.nix` sets both key repeat values in units of about 15 ms:

| Key                | Value | Meaning                                                        |
| ------------------ | ----- | -------------------------------------------------------------- |
| `InitialKeyRepeat` | `68`  | hold a key about 1 s (68 × 15 ms) before it starts repeating   |
| `KeyRepeat`        | `6`   | about 90 ms between repeats (6 × 15 ms), ~11 characters/second |

Lower is faster for both. System Settings > Keyboard only offers slider notches (its shortest delay is 15 and its
fastest rate is 2); smaller values can only be set through `defaults` or this file. Apple's stock values differ
between macOS versions and sources disagree on them, so check a machine with `defaults read -g InitialKeyRepeat`
and `defaults read -g KeyRepeat` rather than trusting a documented default.

### Control Center

`controlCenter.nix` uses nix-darwin's `system.defaults.controlcenter.*`: `true` shows a module's icon in the menu
bar, `false` hides it, and leaving the option unset keeps macOS's own choice. Bluetooth, Sound, Focus and Now
Playing are shown; Display and the battery percentage are hidden.

## OrbStack

`den.aspects.macos.orbstack` (`modules/packages/orbstack.nix`) installs OrbStack from nixpkgs
and keeps its containers and machines on their own APFS volume:

- On every switch (`extraActivation`), the `container-data-volume` script adds an APFS volume named
  `Container Data` to `disk3` (the internal container) if it doesn't exist yet, unlocks and mounts it at
  `/Volumes/Container Data` if needed, encrypts it if it isn't encrypted yet, and enables ownership on it. If this
  fails, for example because `disk3` isn't an APFS container, it prints a warning and the rest of the switch
  carries on.
- A `postActivation` script then creates `/Volumes/Container Data/OrbStack/<user>` (mode 700) for each of the
  host's users.
- Home Manager sets `data_dir` in `~/.orbstack/vmconfig.json` to that directory, keeping the file's other keys.
  This is the setting behind the app's Settings > Storage > Data location; `orb config` has no key for it.
  OrbStack picks it up the next time it starts.

The volume is FileVault-encrypted the same way the Nix installer encrypts the `Nix Store` volume: a random
passphrase is stored in the System keychain (account `Container Data`, service = the volume's UUID) before the
volume is encrypted with it. The volume is locked after every reboot, so the `org.nixos.container-data-volume`
launchd daemon runs the same script at boot to unlock and mount it (log: `/var/log/container-data-volume.log`).

> [!NOTE]
> After the first switch, the System keychain item (account `Container Data`) is the only copy of the volume's
> key. If it's deleted, the volume can't be unlocked and OrbStack's data on it is lost. Save the passphrase
> somewhere safe, such as 1Password:
>
> ```sh
> sudo security find-generic-password -a "Container Data" -w /Library/Keychains/System.keychain
> ```

Existing OrbStack data in `~/.orbstack/data` is not moved (activation warns if it exists).

## App Store apps

Mac App Store apps are installed by `brew bundle` through `mas` (`homebrew.masApps`), which needs you signed in to
the App Store. Each app, or group of related apps, is a `den.aspects.macos.*` aspect in `modules/packages/appstore/`;
Safari extensions have to be turned on in Safari > Settings > Extensions after the
first switch.

Groups:

| Aspect                   | Apps                                                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `macos.iwork`            | Pages, Keynote, Numbers                                                                                                                                      |
| `macos.microsoftOffice`  | Microsoft Word, Excel and PowerPoint; OneDrive                                                                                                               |
| `macos.appleDeveloper`   | Xcode, TestFlight, Developer, Swift Playground                                                                                                               |
| `macos.flexibits`        | Fantastical, Cardhop                                                                                                                                         |
| `macos.pixelmator`       | Pixelmator Pro, Photomator                                                                                                                                   |
| `macos.safariExtensions` | Auto HD FPS for YouTube, Kagi for Safari, Obsidian Web Clipper, Privacy.com for Safari, Sink It, StopTheMadness Pro, Turn Off the Lights for Safari, Vinegar |
| `macos.boardGames`       | Goban, Gomoku                                                                                                                                                |

Single apps: `acorn` (Acorn), `amphetamine` (Amphetamine), `autoMounter` (AutoMounter), `backgroundSwitcher`
(John's Background Switcher), `bookShelves` (BookShelves), `broadcasts` (Broadcasts), `codePeek` (Code Peek+),
`contactsSync` (Contacts Sync), `crystalFetch` (CrystalFetch), `darkroom` (Darkroom), `dropover` (Dropover), `due`
(Due), `flixFixer` (Flix Fixer), `hyperduck` (Hyperduck), `hyperspace`
(Hyperspace), `iris` (Iris), `ivory` (Ivory), `languageTool` (LanguageTool), `ledgerWallet` (Ledger Wallet), `mela`
(Mela), `nepTunes` (NepTunes), `paste` (Paste), `pastel` (Pastel), `reeder` (Reeder), `simpleComic` (Simple
Comic), `stecker` (Stecker), `texStage` (TexStage), `things` (Things), `transmit` (Transmit), `velja` (Velja),
`windowsApp` (Windows App) and `zavala` (Zavala), all under `macos.`.

Elsewhere: `macos._1password` (1Password for Safari, `modules/packages/1password/`), `macos.magnet` (Magnet,
`modules/packages/magnet.nix`) and `tailscale` (Tailscale, `modules/packages/tailscale.nix`) also install App Store
apps.
