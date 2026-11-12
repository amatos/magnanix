# User:      alberth (den.aspects.alberth.mail)
# Platforms: home-manager, darwin (through thunderbird.externalGnupg)
# Purpose:   alberth's Fastmail account in Thunderbird (mail, calendars and
#            contacts), signing and decrypting with the GPG key on their YubiKey.
#
# Notes:
# - Opt-in per host: included from den.aspects.<host>.provides.alberth.
# - Sign-in is OAuth (xoauth2): Thunderbird opens Fastmail's login page the
#   first time and stores the token itself. No app password is needed. CalDAV
#   and CardDAV use the same OAuth sign-in.
# - Mail is stored as maildir (one file per message) instead of Thunderbird's
#   default mbox (one file per folder). This only applies to accounts created
#   with it: switching an existing account's store means letting Thunderbird
#   convert it (Account Settings > Server Settings > Message Storage), not
#   changing the pref.
# - Calendars are keyed by their Fastmail ID, because Home Manager derives
#   Thunderbird's internal calendar ID from the attribute name; their display
#   names are set separately and can change freely.
# - OpenPGP uses GnuPG (thunderbird.externalGnupg) with meta.gpgKey. Import
#   the public key (F41BDBF6171A3BB4.pub.asc) once in Thunderbird's OpenPGP Key
#   Manager. Signing and encrypting are off by default: turn them on per
#   message.
# - Add-ons are force-installed through enterprise policy (ExtensionSettings),
#   from addons.thunderbird.net, and update themselves from there. They can be
#   disabled in the Add-ons Manager but not removed. None of them reads
#   settings from policy, so their settings are made in the add-ons themselves.
#   SmartTemplates and Owl for Exchange need a paid license after their trial.
{ den, lib, ... }:
let
  inherit (den.aspects.alberth) meta;

  # Add-on ID (from its manifest) -> slug on addons.thunderbird.net.
  addons = {
    "sendlater3@kamens.us" = "send-later-3"; # Send Later
    "{8845E3B3-E8FB-40E2-95E9-EC40294818C4}" = "quicktext"; # Quicktext
    "smarttemplate4@thunderbird.extension" = "smarttemplate4"; # SmartTemplates
    "mailmerge@example.net" = "mail-merge"; # Mail Merge
    "{2ab1b709-ba03-4361-abf9-c50b964ff75d}" = "signature-switch"; # Signature Switch
    "languagetool-mailextension@languagetool.org" = "grammar-and-spell-checker"; # LanguageTool
    "expressionsearch@opto.one" = "expression-search-ng"; # Expression Search NG
    "gconversation@xulforum.org" = "gmail-conversation-view"; # Thunderbird Conversations
    "AutoarchiveReloaded@brummolix.addons.mozilla.org" = "autoarchivereloaded"; # AutoarchiveReloaded
    "{a300a000-5e21-4ee0-a115-9ec8f4eaa92b}" = "removedupes"; # Remove Duplicate Messages
    "owl@beonex.com" = "owl-for-exchange"; # Owl for Exchange
    "dkim_verifier@pl" = "dkim-verifier"; # DKIM Verifier
    "hdrtoolslite@dillinger" = "header-tools-improved"; # Header Tools Improved
  };

  maildirStore = "@mozilla.org/msgstore/maildirstore;1";

  # Fastmail calendar ID -> name shown in Thunderbird. The IDs come from a
  # PROPFIND of https://caldav.fastmail.com/dav/calendars/user/<email>/ (the
  # Inbox and Outbox collections there are for scheduling, not calendars).
  # Left out: 2BBCCE76-3DB1-4EC7-A9C7-202FEA054152 (DEFAULT_TASK_CALENDAR_NAME),
  # Fastmail's default tasks calendar, which can't be deleted and isn't used.
  calendars = {
    "2556ba7a-e746-46b4-aff2-afaa4e071b39" = "Calendar (iCloud)";
    "6e7ff7fd-1007-4ed2-a021-e4f50240ba10" = "Personal";
    "957c27ed-7327-4577-a4ff-01c8ee5b4892" = "Shared Parenting";
    "A1195A37-2A56-40FE-91D3-F2391C8BC081" = "DeskMinder";
    "F4EF100E-E844-11EC-8B17-2196AD52101A" = "Calendar (fastmail)";
    "a637cd5d-ddc5-4c01-9870-7960680d1cd0" = "Family";
    "eb82a51d-97af-4e62-be77-9fbdf5b907f4" = "Alberth & Llewellyn";
  };
in
{
  den.aspects.alberth.mail = {
    includes = [
      den.aspects.thunderbird
      den.aspects.thunderbird.externalGnupg
    ];

    homeManager = {
      accounts.email.accounts.fastmail = {
        primary = true;

        # Fills in the IMAP (imap.fastmail.com:993) and SMTP
        # (smtp.fastmail.com:465) servers, with the address as the user name.
        flavor = "fastmail.com";
        address = meta.email;
        realName = meta.fullName;

        # Thunderbird has Fastmail's OAuth client built in.
        imap.authentication = "xoauth2";
        smtp.authentication = "xoauth2";

        gpg = {
          key = meta.gpgKey;
          signByDefault = false;
          encryptByDefault = false;
        };

        thunderbird = {
          enable = true;
          settings = id: {
            "mail.server.server_${id}.storeContractID" = maildirStore;
          };
        };
      };

      # The Fastmail calendars in `calendars`, over CalDAV.
      accounts.calendar.accounts = lib.mapAttrs (calId: displayName: {
        remote = {
          type = "caldav";
          url = "https://caldav.fastmail.com/dav/calendars/user/${meta.email}/${calId}/";
          userName = meta.email;
        };
        thunderbird = {
          enable = true;
          settings = id: { "calendar.registry.calendar_${id}.name" = displayName; };
        };
      }) calendars;

      # Fastmail's main address book, over CardDAV.
      accounts.contact.accounts.Fastmail = {
        remote = {
          type = "carddav";
          url = "https://carddav.fastmail.com/dav/addressbooks/user/${meta.email}/Default/";
          userName = meta.email;
        };
        thunderbird.enable = true;
      };

      # New accounts (including ones added by hand) default to maildir too.
      programs.thunderbird.profiles.default.settings."mail.serverDefaultStoreContractID" = maildirStore;

      # Policies apply to the whole app (every profile). `normal_installed`
      # installs the add-on and keeps it from being removed.
      programs.thunderbird.policies.ExtensionSettings = lib.mapAttrs (_: slug: {
        installation_mode = "normal_installed";
        install_url = "https://addons.thunderbird.net/thunderbird/downloads/latest/${slug}/latest.xpi";
      }) addons;
    };
  };
}
