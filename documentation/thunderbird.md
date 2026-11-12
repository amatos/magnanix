# Thunderbird

`alberth` reads mail in Thunderbird on magnus and fortuna. Each host includes `den.aspects.alberth.mail`
(`modules/users/alberth/mail.nix`) from `den.aspects.<host>.provides.alberth`, which brings in:

- `den.aspects.thunderbird` (`modules/packages/thunderbird.nix`): Thunderbird from nixpkgs (the macOS build
  is in cache.nixos.org) with one Home Manager-managed profile, `default`. On macOS the app is in
  `~/Applications/Home Manager Apps`.
- `den.aspects.thunderbird.externalGnupg`: OpenPGP through GnuPG, for keys on a YubiKey.
- The Fastmail account, its calendars and address book, the message store setting and the add-ons below.

Home Manager writes `profiles.ini` and the profile's `user.js`. Thunderbird applies `user.js` at every start, so
settings made there win over changes made in the app. Profiles created in Thunderbird's own profile manager are
dropped from `profiles.ini` on the next switch.

## Fastmail

- **Mail:** IMAP `imap.fastmail.com:993` and SMTP `smtp.fastmail.com:465`, from Home Manager's `fastmail.com`
  flavor, with `alberth`'s `meta.email` and `meta.fullName`.
- **Sign-in:** OAuth for mail, CalDAV and CardDAV. Thunderbird opens Fastmail's login page the first time and
  stores the token itself; no app password is needed.
- **Calendars:** every Fastmail calendar over CalDAV, listed in `calendars` in `mail.nix` by Fastmail ID. Home
  Manager derives Thunderbird's internal calendar ID from that key, so the display names next to them can change
  without Thunderbird downloading the calendar again. The `Inbox` and `Outbox` collections are for meeting
  invitations, not calendars, and are left out.
- **Contacts:** the `Default` address book over CardDAV, shown as "Fastmail". The shared address book
  (`…Shared`) isn't added.

To list the calendar IDs and names, create a Fastmail app password with CalDAV access (Settings > Privacy &
Security > App passwords) and run:

```sh
read -s 'P?App password: '
curl -s -u "alberth@matos.cc:$P" -X PROPFIND -H 'Depth: 1' -H 'Content-Type: application/xml' \
  --data '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>' \
  https://caldav.fastmail.com/dav/calendars/user/alberth@matos.cc/ \
  | xmllint --format - | grep -E 'href|displayname'
unset P
```

Use `carddav.fastmail.com/dav/addressbooks/user/alberth@matos.cc/` for address books. Delete the app password
afterwards.

## Message store

Mail is stored as maildir (one file per message) instead of Thunderbird's default mbox (one file per folder):
the Fastmail account sets `storeContractID`, and `mail.serverDefaultStoreContractID` makes it the default for
accounts added by hand. Maildir needs no compaction, a bad write damages one message rather than a folder, and
Time Machine copies only new messages.

- The store is chosen when an account is created. Changing the pref for an account that already has mail
  breaks it: convert it in Thunderbird instead (Account Settings > Server Settings > Message Storage).
- Thunderbird's maildir keeps flags in its own `.msf` index, not in the file names, so other maildir tools see
  the messages but not their read or flagged state.
- With IMAP the store is a cache of Fastmail. If it misbehaves, delete the local folders and let Thunderbird
  download them again.

## OpenPGP and the YubiKey

The identity uses `meta.gpgKey` (`F41BDBF6171A3BB4`) as an external GnuPG key, so Thunderbird signs and decrypts
through GPGME with `alberth`'s own `gpg` (`mail.openpgp.alternative_gpg_path`), the same agent and smartcard as
the shell. Signing and encrypting are off by default; turn them on per message.

- Once per host, import the public key (`modules/users/alberth/F41BDBF6171A3BB4.pub.asc`) in Thunderbird's
  OpenPGP Key Manager and mark it accepted. Thunderbird keeps public keys in its own keyring.
- On NixOS, the nixpkgs wrapper puts `gpgme` on `LD_LIBRARY_PATH`.
- On macOS, Thunderbird only looks for `libgpgme.dylib` in its app bundle, `/usr/local/lib`, `/usr/lib`,
  `/opt/local/lib` and `/opt/homebrew/lib`, and `LD_LIBRARY_PATH` does nothing there. Activation links
  `/usr/local/lib/libgpgme.dylib` to Nix's `gpgme`.

## Add-ons

Enterprise policy (`ExtensionSettings`, `normal_installed`) installs each add-on from addons.thunderbird.net,
and it updates itself from there. They can be disabled in the Add-ons Manager but not removed. To add one, put
its ID (`browser_specific_settings.gecko.id` in its `manifest.json`) and its addons.thunderbird.net slug in
`addons` in `mail.nix`.

| Add-on                    | Slug                        | Settings live in      |
| ------------------------- | --------------------------- | --------------------- |
| Send Later                | `send-later-3`              | the add-on's storage  |
| Quicktext                 | `quicktext`                 | the add-on's storage  |
| SmartTemplates (paid)     | `smarttemplate4`            | about:config prefs    |
| Mail Merge                | `mail-merge`                | the add-on's storage  |
| Signature Switch          | `signature-switch`          | the add-on's storage  |
| LanguageTool              | `grammar-and-spell-checker` | the add-on's storage  |
| Expression Search NG      | `expression-search-ng`      | about:config prefs    |
| Thunderbird Conversations | `gmail-conversation-view`   | both                  |
| AutoarchiveReloaded       | `autoarchivereloaded`       | the add-on's storage  |
| Remove Duplicate Messages | `removedupes`               | about:config prefs    |
| Owl for Exchange (paid)   | `owl-for-exchange`          | about:config prefs    |
| DKIM Verifier             | `dkim-verifier`             | the add-on's storage  |
| Header Tools Improved     | `header-tools-improved`     | the add-on's storage  |

None of them reads settings from policy. Settings stored as about:config prefs can be set from Nix in
`programs.thunderbird.profiles.default.settings`; the rest are set in each add-on's options, on each host.
SmartTemplates and Owl for Exchange need a paid license after their trial.
