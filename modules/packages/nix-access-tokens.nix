# Aspect:    den.aspects.nix-access-tokens
# Platforms: nixos, darwin
# Purpose:   Gives Nix a GitHub token (`access-tokens = github.com=<token>`), so the
#            host can fetch the private amatos/secrets input and isn't held to
#            GitHub's rate limit for anonymous requests.
#
# Notes:
# - The token is `github_secrets_repo_access_token` in secrets/common.yaml, a
#   fine-grained PAT with read-only Contents on amatos/secrets. Include this only
#   on hosts that are recipients of common.yaml (not the test VMs).
# - sops-nix renders the setting to a file readable by root and the admin group
#   (`wheel` on NixOS, `admin` on macOS), and the Nix config `!include`s it. Nix
#   skips an `!include` that is missing or that it can't read, so a fresh host
#   before its first decryption, and other users such as `nix-ssh` (remote
#   builds), keep working without the token.
# - See documentation/NIX_SECRETS_PLAN.md, Phase 1.
let
  secret = "github_secrets_repo_access_token";

  # The sops template and the `!include` line, given the admin group's name.
  tokenConfig =
    group:
    { config, ... }:
    {
      sops.secrets.${secret}.sopsFile = ../../secrets/common.yaml;
      sops.templates.nix-access-tokens = {
        content = "access-tokens = github.com=${config.sops.placeholder.${secret}}\n";
        inherit group;
        mode = "0440";
      };
    };

  includeLine = config: "!include ${config.sops.templates.nix-access-tokens.path}";
in
{
  den.aspects.nix-access-tokens = {
    darwin =
      { config, lib, ... }:
      {
        imports = [ (tokenConfig "admin") ];
        # Determinate owns /etc/nix/nix.custom.conf (determinateNix.customSettings),
        # which has no way to express `!include`, so append the line to the file.
        environment.etc."nix/nix.custom.conf".text = lib.mkAfter (includeLine config);
      };

    nixos =
      { config, ... }:
      {
        imports = [ (tokenConfig "wheel") ];
        # Determinate's NixOS module moves the generated nix.conf to
        # /etc/nix/nix.custom.conf, so this lands next to the other settings.
        nix.extraOptions = includeLine config;
      };
  };
}
