# SSH client

`alberth`'s `~/.ssh/config` comes from `den.aspects.alberth.ssh` (`modules/users/alberth/ssh.nix`), which
`alberth` includes on every host. It starts from an empty config (`enableDefaultConfig = false`) and adds these
hosts:

| Host                           | Connects to           | User   |
| ------------------------------ | --------------------- | ------ |
| `github.com`                   | `github.com`          | `git`  |
| `unifi`, `unifi.home.matos.cc` | `unifi.home.matos.cc` | `root` |

`ssh unifi` works without relying on the DNS search domain, because `HostName` is always the fully qualified name.

To add a host, add a `programs.ssh.settings."<patterns>"` entry. The attribute name becomes the `Host` line, so a
space-separated list matches several names.

## 1Password SSH agent

On hosts that include `den.aspects._1password` (`modules/packages/1password/1password.nix`), a `Host *` block
sets `IdentityAgent` to 1Password's agent socket, and `~/.ssh/1Password/config` (1Password's SSH bookmarks) is
included at the top of the file. Turn the agent on in 1Password > Settings > Developer. On other hosts ssh uses its
default keys and agent.
