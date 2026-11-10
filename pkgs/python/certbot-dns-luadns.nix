# Package:   certbot-dns-luadns (certbot plugin; not in nixpkgs)
# Platforms: nixos, darwin (used by modules/packages/certbot.nix)
# Purpose:   Lets certbot prove domain ownership through LuaDNS DNS records,
#            using dns-lexicon (in nixpkgs) to talk to the LuaDNS API.
#
# Notes:
# - Takes its src and version from certbot itself (the same trick nixpkgs uses
#   for its other dns-lexicon plugins, e.g. certbot-dns-ovh), so it never
#   drifts out of sync with the installed certbot/acme.
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
