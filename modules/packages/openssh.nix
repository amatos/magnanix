# Aspect:    den.aspects.openssh
# Platforms: nixos, darwin
# Purpose:   SSH server, public keys only: no passwords, no keyboard-interactive
#            login, no root login. Users' keys come from
#            users.users.<name>.openssh.authorizedKeys (alberth's come from
#            meta.authorizedKeys).
#
# Notes:
# - NixOS: sshd with port 22 open. It also generates
#   /etc/ssh/ssh_host_ed25519_key, which sops-nix decrypts system secrets with.
# - macOS: Apple's sshd (System Settings > General > Sharing > Remote Login),
#   turned on at activation. Settings go in
#   /etc/ssh/sshd_config.d/100-nix-darwin.conf.
{
  den.aspects.openssh = {
    # NixOS: sshd, with port 22 opened in the firewall. It also creates
    # /etc/ssh/ssh_host_ed25519_key, the key sops-nix decrypts system secrets with.
    nixos.services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # macOS: Apple's own sshd, i.e. System Settings → General → Sharing → Remote
    # Login, turned on with launchctl at activation. The settings land in
    # /etc/ssh/sshd_config.d/100-nix-darwin.conf, which macOS's sshd_config includes.
    darwin.services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
      '';
    };
  };
}
