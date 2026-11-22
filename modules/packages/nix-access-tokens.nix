# Aspect:    den.aspects.nix-access-tokens
# Platforms: nixos, darwin
# Purpose:   Gives Nix a GitHub token (`access-tokens = github.com=<token>`), so the
#            host can fetch the private amatos/secrets input and isn't held to
#            GitHub's rate limit for anonymous requests.
#
# Notes:
# - The token is the nix-secrets secret `common/github_secrets_repo_access_token`,
#   a fine-grained PAT with read-only Contents on amatos/secrets. Include this
#   only on hosts that are its recipients in modules/den/_secrets-registry.nix
#   (not the test VMs).
# - nix-secrets renders the setting to a file readable by root and the admin
#   group (`wheel` on NixOS, `admin` on macOS), and the Nix config `!include`s
#   it. Nix skips an `!include` that is missing or that it can't read, so a
#   fresh host before its first decryption, and other users such as `nix-ssh`
#   (remote builds), keep working without the token.
# - LEGACY: the config also `!include`s the file sops-nix rendered before the
#   cutover, which stays in place until the next reboot (NixOS) or sops-nix's
#   removal. On darwin nix-secrets activates from a launchd daemon, after the
#   switch, so this keeps fetching working in between. Drop it with sops-nix
#   (documentation/NIX_SECRETS_PLAN.md, Phase 6).
let
  secret = "common/github_secrets_repo_access_token";
  legacyPath = "/run/secrets/rendered/nix-access-tokens";

  # The template and the `!include` lines, given the admin group's name.
  tokenConfig =
    group:
    { config, ... }:
    {
      security.nix-secrets.secrets.${secret}.enable = true;
      security.nix-secrets.templates.nix-access-tokens = {
        content = "access-tokens = github.com=${config.security.nix-secrets.secrets.${secret}}\n";
        inherit group;
        mode = "0440";
      };
    };

  includeLines = config: ''
    !include ${legacyPath}
    !include ${config.security.nix-secrets.templates.nix-access-tokens.path}
  '';
in
{
  den.aspects.nix-access-tokens = {
    darwin =
      { config, lib, ... }:
      {
        imports = [ (tokenConfig "admin") ];
        # Determinate owns /etc/nix/nix.custom.conf (determinateNix.customSettings),
        # which has no way to express `!include`, so append the lines to the file.
        environment.etc."nix/nix.custom.conf".text = lib.mkAfter (includeLines config);
      };

    nixos =
      { config, ... }:
      {
        imports = [ (tokenConfig "wheel") ];
        # Determinate's NixOS module moves the generated nix.conf to
        # /etc/nix/nix.custom.conf, so this lands next to the other settings.
        nix.extraOptions = includeLines config;
      };
  };
}
