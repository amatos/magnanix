# Test VMs

## Testing changes on darwintron

`darwintron` is a disposable [Tart](https://tart.run) VM on `magnus` for trying a change before it lands. It is
deliberately minimal: to test something, add its aspect to `modules/hosts/virtual/darwintron.nix` on a branch. Its primary
user is `ephemeral`, whose secrets hold fake values, and it can't read `common.yaml` or `alberth.yaml`.

Run these inside `nix develop` on `magnus`. Only committed code is tested.

```sh
darwintron-vm seed                # once: macOS, Determinate Nix and the ephemeral user
darwintron-vm baseline            # after main moves: the seed with main applied
darwintron-vm test my-branch      # switch a clone to my-branch, check, reboot, roll back, delete
darwintron-vm test my-branch --fresh   # from the seed, as a first install (nothing to diff or roll back)
darwintron-vm test my-branch --keep    # keep the VM afterwards; then `ssh` and `destroy`
```

A failed test keeps its VM for inspection. `darwintron-vm ssh` opens a shell on it and `darwintron-vm destroy`
deletes it. Each test checks the canary secrets, the login shell and the hostname, and prints an `nvd` diff when
starting from the baseline.

The VM keeps one identity however often it is rebuilt. `secrets/bootstrap/darwintron.yaml` holds its private keys,
encrypted to the YubiKeys and `alberth_magnus`. The script decrypts them on `magnus`, pipes them in over SSH before
activation, and removes them before saving an image, so neither image contains them. The public halves are
`host_darwintron` and `ephemeral_darwintron` in `.sops.yaml`.

The image is pinned by digest at the top of `pkgs/darwintron-vm.sh`. YubiKeys, 1Password, the App Store and audio
hardware can't be tested in the VM.

## Testing changes on nixostron

`nixostron` is a disposable, headless NixOS VM, built for whichever architecture the machine running it has:
`nixostron-aarch64` under Tart on `magnus`, and `nixostron-x86_64` under QEMU on `muninn` (or any x86_64 NixOS host
with KVM). Both hosts share `den.aspects.nixostron` in `modules/hosts/virtual/nixostron.nix`; to test something, add its
aspect there on a branch. Its disk is described with [disko](https://github.com/nix-community/disko) (GPT, a 1 GiB
ESP at `/boot`, ext4 root on `/dev/vda`). The only way in is SSH as `ephemeral` with the access key.

Run these inside `nix develop`. Only committed code is tested.

On `magnus`, the workflow matches darwintron's. The seed is a stock Ubuntu image; [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
kexecs from it into the NixOS installer, partitions the disk with disko and installs. magnus can't build Linux,
so the guest builds its own system (`--build-on remote`); nearly everything comes from the binary cache.

```sh
nixostron-vm seed                 # once: stock Ubuntu with the access key
nixostron-vm baseline             # after main moves: the seed with main installed by nixos-anywhere
nixostron-vm test my-branch       # switch a clone to my-branch, check, reboot, roll back, delete
nixostron-vm test my-branch --fresh    # install my-branch onto a seed clone with nixos-anywhere
nixostron-vm test my-branch --keep     # keep the VM afterwards; then `ssh` and `destroy`
```

On `muninn` (and later `fortuna`), each test is a fresh build, so there is no seed, baseline or rollback:

```sh
nixostron-vm test my-branch           # nixos-rebuild build-vm, boot, check, reboot, check, delete
nixostron-vm test my-branch --disko   # the same on disko's vmWithDisko, which boots the real disk layout
nixostron-vm test my-branch --keep    # keep the VM afterwards (SSH on localhost:2222); then `ssh` and `destroy`
```

A failed test keeps its VM for inspection. Each test checks that the system reaches `running` with no failed units,
both canary secrets decrypt, the hostname and login shell are right, and sshd refuses passwords. On `magnus` a
test from the baseline also prints `nix store diff-closures`.

The VM keeps one identity however often it is rebuilt. `secrets/bootstrap/nixostron.yaml` holds its host key,
`ephemeral`'s age key and the access key, encrypted to the YubiKeys, `alberth_magnus` and (once added)
`alberth_muninn`. The script decrypts them on the host and puts them in `/var/lib/nixostron-keys` on the guest: via
nixos-anywhere's `--extra-files` or SSH on Tart, and as a read-only QEMU share on muninn. The `nixostron-keys`
activation script installs them before sops-nix runs, and the Tart script removes them before saving an image. The
public halves are `host_nixostron` and `ephemeral_nixostron` in `.sops.yaml`.

`nix flake check` on a Linux machine also builds the nixostron host for its architecture.

The Ubuntu image is pinned by digest at the top of the Tart section of `pkgs/nixostron-vm.sh`.
