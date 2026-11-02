# certbot-dns-luadns — not in nixpkgs; packaged locally.
# Uses dns-lexicon (which IS in nixpkgs) to talk to the LuaDNS API.
#
# Tracks certbot's own src/version (same trick nixpkgs uses for its other
# dns-lexicon-based plugins, e.g. certbot-dns-ovh) instead of pinning a
# separate tag, so the plugin never drifts out of sync with whatever
# certbot/acme version is actually installed alongside it.
#
# Installed and scheduled by modules/packages/certbot.nix, which also describes
# how certificates are issued.

{
  buildPythonPackage,
  certbot,
  acme,
  dns-lexicon,
  setuptools,
}:

buildPythonPackage {
  pname = "certbot-dns-luadns";
  inherit (certbot) src version;

  sourceRoot = "${certbot.src.name}/certbot-dns-luadns";

  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [
    certbot
    acme
    dns-lexicon
  ];
  doCheck = false;

  meta = certbot.meta // {
    description = "LuaDNS DNS Authenticator plugin for Certbot";
  };
}
