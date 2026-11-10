# Adding hosts and users

## Adding a host

1. Copy `modules/hosts/_darwin_template.nix` or `_nix_template.nix` to `modules/hosts/<hostname>.nix`.
2. Replace `CHANGE_HOSTNAME` and `CHANGE_USERNAME`, and set the platform and `system.stateVersion`.
3. For secrets, add the host's age key (and the user's per-machine key) and a creation rule to `.sops.yaml`, then
   create `secrets/hosts/<hostname>.yaml`. No Nix change is needed: the `sops` aspect points each host at
   `secrets/hosts/<hostname>.yaml` by name.
4. Adjust the host's apps in `den.aspects.<hostname>` (see [Features](architecture.md#features)). The templates start with a default
   set: `_1password`, `browsers`, `fonts`, `ghostty`, `openssh`, `audio` and `zed`, plus `bluetooth` on NixOS.
5. On NixOS, put the machine's generated `hardware-configuration.nix` next to the host file, in a
   `modules/hosts/<hostname>/` directory, as `_hardware-configuration.nix`. The leading `_` stops import-tree loading
   it as a flake module. Import it from the host's `nixos` block (see `muninn/muninn.nix`). The boot loader comes from `base`
   (`systemdBoot`).
6. New files must be tracked by git for flakes to see them (`git add` them).

## Adding a user

1. Copy `modules/users/_user_template/` to `modules/users/<username>/`.
2. Replace `CHANGE_USERNAME` and set `home.stateVersion`.
3. Add the user to a host with `den.hosts.<system>.<host>.users.<username> = { };`.
4. Include `den.batteries.host-aspects` if the user should get the `homeManager` parts of the host's apps.
5. Optionally add a `meta` set (see [User metadata](architecture.md#user-metadata)) and include features from `modules/packages/`.
6. For secrets, add the user's per-machine age key and a creation rule to `.sops.yaml`, then create
   `secrets/users/<username>.yaml`.
