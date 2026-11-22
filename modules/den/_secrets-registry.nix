# Aspect:    none (plain data, not a module; import-tree skips `_` files)
# Platforms: n/a
# Purpose:   Who can decrypt each nix-secrets secret: recipient aliases and one
#            entry per secret. Read by the nix-secrets aspect (every host gets
#            every entry, disabled, with these recipients) and by the
#            `secretsAdmin` flake output the CLI edits and rekeys against.
#            Replaces .sops.yaml, keyed by secret instead of by file.
#
# Notes:
# - `admins` is added to every secret by _nix-secrets-shared.nix.
# - Host recipients are the host's `ssh-ed25519` public key, not its
#   `ssh-to-age` form: nix-secrets decrypts with the SSH key directly. Each one
#   converts (`ssh-to-age`) to the host's key in .sops.yaml.
# - After changing a secret's recipients, run `secrets rekey` and push
#   amatos/secrets.
# - See documentation/NIX_SECRETS_PLAN.md (§4 has the mapping from sops).
{
  aliases = {
    # One age-plugin-yubikey recipient per YubiKey (`age-plugin-yubikey --list`)
    admins = [
      "age1yubikey1qv0utu8hcayj3xeppwjuckzmrgd0ltjuq59ffmwd6t9f2m7depa2sl0ne87"
      "age1yubikey1qtn8y2ad0vr9ddazfsxy4fmlt64kknhjsll2xvfgekck3n0dc0xjvf5rah6"
      "age1yubikey1qgmkn4s840hwg4kfazjn6u4r2nq9utl60chscraq4sqg9jsf0wleu5eldvv"
      "age1yubikey1qtkf5924nev2a5vqncdurp729tq6xmdf27y6x95fv7kk5zje5vqr6umpnj8"
      "age1yubikey1q0pmgm34s0ckw8jj9auzlvm5mc6mpxxgc5syu0aw55cqu2hnm7krqrnq60a"
      "age1yubikey1qt9a6xc0nzpe484kzeuw55hsm4shu3ug9j6m4ngtsexqrgptd6zfx596dqn"
    ];

    # Hosts: /etc/ssh/ssh_host_ed25519_key.pub (or `ssh-keyscan -t ed25519 <host>`).
    # The test VMs' private halves are bootstrap secrets below.
    host_magnus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAHK1L1McBEr1LQ2jM4wov51Lav8sCDs/dZOAaG/hWqV";
    host_muninn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDnw8CzTXukohE1iQu3LBAJlpAxJWGCLfOpRcWWK8Frg";
    host_fortuna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFsOjzSAXwa4AZFoumRkmXhY3k4+ni9Mj9rKoJ6brW+";
    host_tenabrae = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFPmFkHVLcDzfbP0dVWUVB4CfiuWldbBdTWLEsxdacmn";
    host_darwintron = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDrro8f7wv2amSPigdSOWgNvznzO6dgjut0FYLn1marj";
    host_nixostron = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHlrOivwijJm1MRXBiSaiSpZasjcAF/ZRVSteuUsrFvV";

    # Home Manager: per-machine user keys (`age-keygen -y ~/.config/sops-nix/key.txt`)
    alberth_magnus = "age1e9m0g8y8g6270wjqnpexm3x8fvntfyvuf3d4td0hge3hzkgezugsm6gh8l";
    alberth_muninn = "age1lkrmja7y0ru7yqfgckumgzzakgs06lsvmleysvrl9tm0xdp3sa6q7p84fn";
    alberth_fortuna = "age1qj8zxqx8avzy2j2hkvh0pat5va5la0ayz0xfuqcee3gl5a5vtvfsdsrgty";
    ephemeral_darwintron = "age1rd88xaq8el7hm5rn3en6jhy8elfdn8z0elnfrd63q74vsxmanvascxh5sd";
    ephemeral_nixostron = "age1t7ewwhp7ywczmqz0ycvc8q0pjs96h4mqkzqj3nvucapupqy2wcrqvnkqw3";
  };

  # Secret name (its path in the storage, without `.enc`) -> recipients besides `admins`
  secrets = {
    # Shared between hosts
    # macOS hosts never use the NixOS login password, so magnus isn't a recipient.
    "common/alberth_password" = [
      "host_muninn"
      "host_fortuna"
      "host_tenabrae"
    ];
    # Only the hosts that include `certbot`.
    "common/certbot_luadns" = [
      "host_magnus"
      "host_muninn"
      "host_fortuna"
    ];
    # The hosts that include `nix-access-tokens`.
    "common/github_secrets_repo_access_token" = [
      "host_magnus"
      "host_muninn"
      "host_fortuna"
      "host_tenabrae"
    ];

    # One host each
    "hosts/magnus/attic_push_token" = [ "host_magnus" ];
    "hosts/fortuna/attic_push_token" = [ "host_fortuna" ];
    "hosts/muninn/attic_push_token" = [ "host_muninn" ];
    "hosts/muninn/atticd_env" = [ "host_muninn" ];
    "hosts/muninn/fastmail_smtp_password" = [ "host_muninn" ];
    "hosts/tenabrae/pihole_env" = [ "host_tenabrae" ];
    "hosts/tenabrae/wireless_env" = [ "host_tenabrae" ];
    "hosts/darwintron/canary" = [ "host_darwintron" ];
    "hosts/nixostron/canary" = [ "host_nixostron" ];

    # Home Manager. The espanso name keeps `.yml`: Espanso resolves the symlink and
    # rejects match files without an extension.
    "users/alberth/espanso/street-address.yml" = [
      "alberth_magnus"
      "alberth_muninn"
      "alberth_fortuna"
    ];
    "users/ephemeral/canary" = [
      "ephemeral_darwintron"
      "ephemeral_nixostron"
    ];

    # Test VM bootstrap keys, read on magnus (and muninn for nixostron) by the VM
    # scripts. No host enables these. The public halves aren't stored: the scripts
    # derive them with `ssh-keygen -y -f`.
    "bootstrap/darwintron/host_key" = [ "alberth_magnus" ];
    "bootstrap/darwintron/user_key" = [ "alberth_magnus" ];
    "bootstrap/darwintron/access_key" = [ "alberth_magnus" ];
    "bootstrap/nixostron/host_key" = [
      "alberth_magnus"
      "alberth_muninn"
    ];
    "bootstrap/nixostron/user_key" = [
      "alberth_magnus"
      "alberth_muninn"
    ];
    "bootstrap/nixostron/access_key" = [
      "alberth_magnus"
      "alberth_muninn"
    ];
  };
}
