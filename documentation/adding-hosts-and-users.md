# Adding hosts and users

## Adding a host

1. Copy `modules/hosts/templates/_darwin_template.nix` or `_nix_template.nix` to
   `modules/hosts/<hostname>/<hostname>.nix`.
2. Replace `CHANGE_HOSTNAME` and `CHANGE_USERNAME`, and set the platform and `system.stateVersion`.
3. For secrets, add the host's age key (and the user's per-machine key) and a creation rule to `.sops.yaml`, then
   create `secrets/hosts/<hostname>.yaml`. No Nix change is needed: the `sops` aspect points each host at
   `secrets/hosts/<hostname>.yaml` by name.
4. Adjust the host's apps in `den.aspects.<hostname>` (see [Features](architecture.md#features)). The templates start with a default
   set: `_1password`, `browsers`, `fonts`, `ghostty`, `openssh`, `audio` and `zed`, plus `bluetooth` on NixOS.
5. On NixOS, put the machine's generated `hardware-configuration.nix` next to the host file, in
   `modules/hosts/<hostname>/`, as `_hardware-configuration.nix`. The leading `_` stops import-tree loading
   it as a flake module. Import it from the host's `nixos` block (see `muninn/muninn.nix`). The boot loader comes from `base`
   (`systemdBoot`). A board without UEFI, such as a Raspberry Pi, overrides it instead; `tenabrae/tenabrae.nix`
   boots an SD image through U-Boot and extlinux, and needs no hardware configuration.
6. Add the host to `default_hosts` in `modules/users/alberth/scripts/update-all-magnanix`. Every real host
   belongs there; only the test VMs (darwintron, nixostron) and CI's ephemeral machines are left out. The script's
   tests check the list against `modules/hosts`. A host too small to evaluate the flake also goes in
   `build_here_hosts`, so the script builds it elsewhere instead of running `deploy-magnanix` on it.
7. New files must be tracked by git for flakes to see them (`git add` them).

## Adding a user

1. Copy `modules/users/_user_template/` to `modules/users/<username>/`.
2. Replace `CHANGE_USERNAME` and set `home.stateVersion`.
3. Add the user to a host with `den.hosts.<system>.<host>.users.<username> = { };`.
4. Include `den.batteries.host-aspects` if the user should get the `homeManager` parts of the host's apps.
5. Optionally add a `meta` set (see [User metadata](architecture.md#user-metadata)) and include features from `modules/packages/`.
6. For secrets, add the user's per-machine age key and a creation rule to `.sops.yaml`, then create
   `secrets/users/<username>.yaml`.
