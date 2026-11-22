# Aspect:    none (plain function, not a module; import-tree skips `_` files)
# Platforms: n/a
# Purpose:   The `security.nix-secrets` settings every configuration shares, so
#            hosts and the `secretsAdmin` output can't disagree on storage or
#            recipients. Call with `import ./_nix-secrets-shared.nix { inherit inputs lib; }`.
#
# Notes:
# - Every secret in the registry is declared, disabled, with its registry
#   recipients forced (plus `admins`). Aspects only set `enable = true` (and
#   owner, path, ...), so a secret's recipients are the same everywhere, and
#   `rekey` from any configuration produces the same files.
# - The storage is the private `secrets` input (amatos/secrets). Edit it in a
#   local clone with the dev shell's `secrets` command, push, then
#   `nix flake update secrets`.
{ inputs, lib }:
let
  registry = import ./_secrets-registry.nix;
in
{
  enable = true;
  storage = inputs.secrets;
  # The CLI comes from the dev shell (`secrets`), not every host's PATH.
  installPackage = false;
  recipientAliases = registry.aliases;
  secrets = lib.mapAttrs (_: recipients: {
    enable = lib.mkDefault false;
    recipients = lib.mkForce ([ "admins" ] ++ recipients);
  }) registry.secrets;
}
