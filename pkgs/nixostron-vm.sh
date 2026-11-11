# Build and test the disposable nixostron VM. Run from the repo inside `nix develop`.
#
# On magnus (macOS, Tart, nixostron-aarch64):
#
#   nixostron-vm seed                  build nixostron-seed (stock Ubuntu with the access key)
#   nixostron-vm baseline [ref]        build nixostron-baseline (seed + nixos-anywhere ref,
#                                      default main)
#   nixostron-vm test <ref> [--fresh] [--keep]
#                                      switch a throwaway clone of the baseline to ref.
#                                      --fresh installs ref onto a seed clone with
#                                      nixos-anywhere instead; --keep keeps it on success
#
# On an x86_64 NixOS host with KVM, e.g. muninn (QEMU, nixostron-x86_64):
#
#   nixostron-vm test <ref> [--disko] [--keep]
#                                      boot ref with `nixos-rebuild build-vm`. --disko boots
#                                      disko's vmWithDisko instead, on the real disk layout
#
# On both:
#
#   nixostron-vm ssh                   open a shell on the running nixostron
#   nixostron-vm destroy               stop and delete nixostron
#
# Private keys are never stored in an image: they are decrypted on the host for each
# boot and removed again before an image is saved.

user="ephemeral"

repo="$(git rev-parse --show-toplevel)"
bootstrap="$repo/secrets/bootstrap/nixostron.yaml"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nixostron-vm"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# The user's own age key (alberth_magnus, alberth_muninn) if there is one; otherwise
# sops falls back to the dev shell's SOPS_AGE_KEY_CMD, i.e. a plugged-in YubiKey.
if [ -f "$HOME/.config/sops-nix/key.txt" ]; then
  export SOPS_AGE_KEY_FILE="$HOME/.config/sops-nix/key.txt"
fi

case "$(uname -s)" in
  Darwin)
    backend="tart"
    host="nixostron-aarch64"
    port=22
    ;;
  Linux)
    backend="qemu"
    host="nixostron-x86_64"
    port=2222
    ip="127.0.0.1"
    ;;
  *)
    printf 'error: unsupported platform %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

log() { printf '> %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

secret() {
  (umask 077 && sops -d --extract "[\"$1\"]" "$bootstrap" >"$work/$1")
}

access_key() {
  secret access_key
  chmod 600 "$work/access_key"
}

# Options shared by ssh and nixos-anywhere. -F /dev/null (ssh only) skips the user's
# config, whose `*` rule points at the 1Password agent. Host keys aren't checked: the
# address is a local NAT lease or a forwarded port, and the key changes on injection.
ssh_opts=(-o IdentitiesOnly=yes -o IdentityAgent=none -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=5 -o ServerAliveInterval=30)

guest() {
  local login="$1"
  shift
  ssh -F /dev/null -i "$work/access_key" "${ssh_opts[@]}" -p "$port" "$login@$ip" "$@"
}

wait_for_ssh() {
  local login="$1" _
  for _ in $(seq 1 150); do
    if guest "$login" true 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  die "SSH to $login@$ip:$port did not come up"
}

# --- Checks (both backends) -------------------------------------------------------

expected_recipient() {
  # Reads the checked-out .sops.yaml so a ref with different keys fails here, not mid-switch.
  grep -F "&$1 " "$work/src/.sops.yaml" | awk '{print $NF}'
}

check_keys() {
  local host_age user_age
  host_age="$(ssh-keygen -y -f "$work/host_key" | ssh-to-age)"
  user_age="$(age-keygen -y "$work/user_key")"
  [ "$host_age" = "$(expected_recipient host_nixostron)" ] ||
    die "the bootstrap host key is not host_nixostron in .sops.yaml"
  [ "$user_age" = "$(expected_recipient ephemeral_nixostron)" ] ||
    die "the bootstrap user key is not ephemeral_nixostron in .sops.yaml"
  log "keys match .sops.yaml"
}

decrypt_keys() {
  secret host_key
  secret host_key_pub
  secret user_key
  check_keys
}

check_canaries() {
  # The Home Manager one is decrypted by a user service, which starts with the session.
  local system_value home_value _
  for _ in $(seq 1 30); do
    system_value="$(guest "$user" 'sudo cat /run/secrets/canary' 2>/dev/null || true)"
    home_value="$(guest "$user" 'cat ~/.config/sops-nix/secrets/canary' 2>/dev/null || true)"
    if [ "$system_value" = "nixostron-system-canary" ] && [ "$home_value" = "ephemeral-home-canary" ]; then
      log "both canaries decrypted"
      return 0
    fi
    sleep 2
  done
  [ "$system_value" = "nixostron-system-canary" ] || die "system canary did not decrypt"
  die "Home Manager canary did not decrypt"
}

check_system() {
  local state
  state="$(guest "$user" 'systemctl is-system-running --wait' || true)"
  if [ "$state" != "running" ]; then
    guest "$user" 'systemctl --failed --no-legend' >&2 || true
    die "system is $state, not running"
  fi
  check_canaries
  [ "$(guest "$user" 'hostname')" = "nixostron" ] || die "wrong hostname"
  [ "$(guest "$user" "getent passwd $user | cut -d: -f7")" = "/run/current-system/sw/bin/zsh" ] ||
    die "login shell is not Nix zsh"
  # Newer OpenSSH prints keywords in mixed case (PasswordAuthentication), older in lower.
  local sshd_config
  sshd_config="$(guest "$user" 'sudo sshd -T')"
  grep -qix 'passwordauthentication no' <<<"$sshd_config" ||
    die "sshd allows password authentication"
  log "system checks passed"
}

send_source() {
  log "checking out $1 ($(git rev-parse --short "$1"))"
  mkdir -p "$work/src"
  git archive "$1" | tar -x -C "$work/src"
}

# --- Tart (magnus) ----------------------------------------------------------------

# Pinned so the seed only changes when this line does. Ubuntu 24.04, whose only job is
# to be a Linux with SSH that nixos-anywhere can kexec into its installer from.
image="ghcr.io/cirruslabs/ubuntu@sha256:97166c84ea5f102be33d2959f70e83861a36bd749f1715ab669d93e6c9f31476"
# The installer nixos-anywhere kexecs into. Its default (nixos-25.05) runs an older
# udevd than the disko script built from our nixpkgs, and a newer `udevadm settle`
# returns at once against an older udevd, so mkfs runs before the partition links
# exist. Keep this on the release closest to our nixpkgs.
kexec_image="https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz"
# The guest builds its own system, so install_nixos points it at this flake's Attic cache on muninn
# (see modules/packages/attic.nix), which CI fills. Over Tailscale, so it works away
# from the LAN too: the VM's traffic goes out through magnus.
attic_substituter="http://muninn.ts.matos.cc:8080/magnanix"
attic_public_key="magnanix:CqwRoN5bzF5FNtDByVxLzNm/O8lpZ+++pVopZr80TLY="
seed_vm="nixostron-seed"
baseline_vm="nixostron-baseline"
test_vm="nixostron"
# The image's stock login, with passwordless sudo
seed_user="admin"
cpus=8
memory_mb=12288
disk_gb=50

require_tart() { [ "$backend" = "tart" ] || die "$1 is only available on macOS (Tart)"; }

# Not `tart get`, which fails while a VM is running.
vm_exists() { [ -d "${TART_HOME:-$HOME/.tart}/vms/$1" ]; }

boot() {
  mkdir -p "$state_dir"
  log "booting $1"
  nohup tart run --no-graphics "$1" >"$state_dir/$1.log" 2>&1 &
  disown
  ip="$(tart ip --wait 180 "$1")"
  log "$1 is at $ip"
}

wait_for_reboot() {
  sleep 15
  ip="$(tart ip --wait 180 "$1")"
  wait_for_ssh "$user"
}

shut_down() {
  log "shutting down $1"
  guest "$user" 'sudo poweroff' || true
  local _
  for _ in $(seq 1 60); do
    if [ "$(tart get --format json "$1" 2>/dev/null | jq -r .Running)" = "false" ]; then
      return 0
    fi
    sleep 2
  done
  log "$1 did not stop cleanly; forcing it"
  tart stop "$1"
}

# Partitions, formats and installs $host from $work/src onto the running Ubuntu VM.
# The build runs on the guest (magnus can't build Linux). The keys land in the staging
# directory that the `nixostron-keys` activation script installs from on first boot.
#
# The kexec installer asks for a lease with a DUID client ID where Ubuntu used its MAC,
# so macOS's DHCP server gives it a new address and nixos-anywhere would wait on the
# old one forever. So the kexec phase runs on its own, the installer's new address is
# read from the lease file, and the remaining phases run against that.
leases="/var/db/dhcpd_leases"

# Prints "ip lease" for each nixos-installer entry in the lease file.
installer_leases() {
  awk -F= '
    /^\{/ { name = ""; addr = ""; lease = "" }
    $1 ~ /name$/ { name = $2 }
    $1 ~ /ip_address$/ { addr = $2 }
    $1 ~ /lease$/ { lease = $2 }
    /^\}/ && name == "nixos-installer" { print addr, lease }
  ' "$leases" 2>/dev/null || true
}

install_nixos() {
  log "installing $host with nixos-anywhere"
  local stage="$work/extra/var/lib/nixostron-keys"
  mkdir -p "$stage"
  chmod 700 "$work/extra/var/lib/nixostron-keys"
  cp "$work/host_key" "$work/host_key_pub" "$work/user_key" "$stage/"
  local opts=() opt
  for opt in "${ssh_opts[@]}"; do
    [ "$opt" = "-o" ] || opts+=(--ssh-option "$opt")
  done
  local na=(nixos-anywhere --flake "$work/src#$host" --build-on remote
    --extra-files "$work/extra" -i "$work/access_key" "${opts[@]}")

  installer_leases >"$work/leases.before"
  log "kexecing into the NixOS installer"
  "${na[@]}" --phases kexec --kexec "$kexec_image" \
    --target-host "$seed_user@$ip" >"$work/kexec.log" 2>&1 &
  local kexec_pid=$! new="" _
  for _ in $(seq 1 150); do
    new="$(installer_leases | { grep -vxFf "$work/leases.before" || true; } | tail -n 1 | cut -d' ' -f1)"
    [ -n "$new" ] && break
    if ! kill -0 "$kexec_pid" 2>/dev/null; then
      cat "$work/kexec.log" >&2
      die "the kexec phase exited before the installer took a lease"
    fi
    sleep 2
  done
  kill "$kexec_pid" 2>/dev/null || true
  wait "$kexec_pid" 2>/dev/null || true
  if [ -z "$new" ]; then
    cat "$work/kexec.log" >&2
    die "the installer did not take a DHCP lease"
  fi
  ip="$new"
  log "the installer is at $ip"
  wait_for_ssh root

  # nixos-anywhere builds through an ssh-ng store whose daemon ignores substituters
  # passed by the client, and only copies the flake's `substituters`, not the
  # `extra-substituters` the Attic cache is in. Root's own nix.conf is trusted.
  guest root "mkdir -p ~/.config/nix && cat >> ~/.config/nix/nix.conf" <<EOF
extra-substituters = $attic_substituter
extra-trusted-public-keys = $attic_public_key
connect-timeout = 5
EOF

  "${na[@]}" --phases disko,install,reboot --target-host "root@$ip"
  wait_for_reboot "$1"
}

inject_keys() {
  log "injecting keys"
  local f
  for f in host_key host_key_pub user_key; do
    guest "$user" "sudo sh -c 'umask 077; mkdir -p /var/lib/nixostron-keys; cat > /var/lib/nixostron-keys/$f'" <"$work/$f"
  done
}

remove_keys() {
  # Decrypted secrets live on sops-nix's RAM disks, so they don't reach the saved image.
  # sshd generates a new, unrelated host key the next time it starts.
  log "removing keys"
  guest "$user" 'rm -f ~/.config/sops-nix/key.txt; sudo rm -rf /var/lib/nixostron-keys /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub'
}

apply() {
  log "applying configuration"
  tar -C "$work/src" -cf - . |
    guest "$user" 'rm -rf ~/magnanix; mkdir -p ~/magnanix; tar -xf - -C ~/magnanix'
  guest "$user" "sudo nixos-rebuild switch --flake ~/magnanix#$host"
}

build_seed() {
  require_tart seed
  vm_exists "$seed_vm" && die "$seed_vm exists; delete it first with: tart delete $seed_vm"
  secret access_key_pub
  access_key

  log "cloning $image"
  tart clone "$image" "$seed_vm"
  tart set "$seed_vm" --cpu "$cpus" --memory "$memory_mb" --disk-size "$disk_gb"
  boot "$seed_vm"

  log "installing the access key for $seed_user"
  local _ up=""
  for _ in $(seq 1 90); do
    if SSHPASS="admin" sshpass -e ssh -F /dev/null -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=5 \
      -o PubkeyAuthentication=no "$seed_user@$ip" \
      'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys' <"$work/access_key_pub" 2>/dev/null; then
      up=1
      break
    fi
    sleep 2
  done
  [ -n "$up" ] || die "SSH to $seed_user@$ip did not come up"
  guest "$seed_user" 'sudo -n true' || die "$seed_user has no passwordless sudo, which nixos-anywhere needs"

  guest "$seed_user" 'sudo poweroff' || true
  for _ in $(seq 1 60); do
    [ "$(tart get --format json "$seed_vm" 2>/dev/null | jq -r .Running)" = "false" ] && break
    sleep 2
  done
  log "$seed_vm is ready"
}

build_baseline() {
  require_tart baseline
  local ref="${1:-main}"
  vm_exists "$seed_vm" || die "$seed_vm does not exist; run: nixostron-vm seed"
  vm_exists "$baseline_vm" && die "$baseline_vm exists; delete it first with: tart delete $baseline_vm"
  access_key
  send_source "$ref"
  decrypt_keys

  tart clone "$seed_vm" "$baseline_vm"
  boot "$baseline_vm"
  wait_for_ssh "$seed_user"
  install_nixos "$baseline_vm"
  check_system
  remove_keys
  shut_down "$baseline_vm"
  mkdir -p "$state_dir"
  git rev-parse "$ref" >"$state_dir/baseline-rev"
  log "$baseline_vm is ready at $ref"
}

tart_test() {
  local ref="$1" fresh="$2" keep="$3" from="$baseline_vm" previous="" current
  [ -n "$fresh" ] && from="$seed_vm"
  vm_exists "$from" || die "$from does not exist"
  vm_exists "$test_vm" && die "$test_vm exists; inspect it or run: nixostron-vm destroy"
  if [ -z "$fresh" ] && [ "$(cat "$state_dir/baseline-rev" 2>/dev/null)" != "$(git rev-parse main)" ]; then
    log "warning: $baseline_vm was not built from the current main"
  fi
  access_key
  send_source "$ref"
  decrypt_keys

  tart clone "$from" "$test_vm"
  boot "$test_vm"
  if [ -n "$fresh" ]; then
    wait_for_ssh "$seed_user"
    install_nixos "$test_vm"
    check_system
  else
    wait_for_ssh "$user"
    inject_keys
    previous="$(guest "$user" 'readlink -f /run/current-system')"
    apply
    check_system
    current="$(guest "$user" 'readlink -f /run/current-system')"
    if [ "$current" = "$previous" ]; then
      # Same system as the baseline (e.g. testing main): no new generation to undo.
      log "$ref builds the baseline's system; nothing to roll back"
      previous=""
    else
      guest "$user" "nix store diff-closures $previous $current" || true
    fi
  fi

  log "rebooting"
  guest "$user" 'sudo reboot' || true
  wait_for_reboot "$test_vm"
  check_system

  if [ -n "$previous" ]; then
    log "rolling back"
    # --no-reexec: otherwise nixos-rebuild first rebuilds itself from <nixpkgs/nixos>,
    # and the guest has no NIX_PATH.
    guest "$user" 'sudo nixos-rebuild switch --rollback --no-reexec'
    [ "$(guest "$user" 'readlink -f /run/current-system')" = "$previous" ] ||
      die "rollback did not restore the previous system"
    log "rollback restored the previous system"
  fi

  if [ -n "$keep" ]; then
    log "keeping $test_vm at $ip (nixostron-vm ssh, nixostron-vm destroy)"
  else
    tart stop "$test_vm"
    tart delete "$test_vm"
    log "$ref passed; $test_vm deleted"
  fi
}

# --- QEMU (muninn, fortuna) -------------------------------------------------------

pid_file="$state_dir/qemu.pid"
disk_dir="$state_dir/disk"

qemu_running() { [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; }

qemu_stop() {
  local pid _
  qemu_running || return 0
  pid="$(cat "$pid_file")"
  guest "$user" 'sudo poweroff' 2>/dev/null || true
  for _ in $(seq 1 60); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 2
  done
  if kill -0 "$pid" 2>/dev/null; then
    log "nixostron did not stop cleanly; killing it"
    # setsid made the runner a process group leader; take QEMU and virtiofsd with it.
    kill -- "-$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

qemu_test() {
  local ref="$1" disko="$2" keep="$3" runner
  [ -e /dev/kvm ] || die "/dev/kvm is missing; nixostron needs KVM"
  qemu_running && die "nixostron is already running; inspect it or run: nixostron-vm destroy"
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    die "port $port is already in use"
  fi
  access_key
  send_source "$ref"

  # Kept outside $work so --keep can leave the VM running after the script exits
  rm -rf "$disk_dir"
  mkdir -p "$disk_dir/keys"
  chmod 700 "$disk_dir" "$disk_dir/keys"
  decrypt_keys
  cp "$work/host_key" "$work/host_key_pub" "$work/user_key" "$disk_dir/keys/"

  if [ -n "$disko" ]; then
    log "building vmWithDisko for $host"
    nix build --out-link "$disk_dir/result" \
      "$work/src#nixosConfigurations.$host.config.system.build.vmWithDisko"
    runner="$disk_dir/result/bin/disko-vm"
  else
    log "building $host with nixos-rebuild build-vm"
    (cd "$disk_dir" && nixos-rebuild build-vm --flake "$work/src#$host")
    runner="$(echo "$disk_dir"/result/bin/run-*-vm)"
  fi

  log "booting nixostron"
  (
    cd "$disk_dir"
    NIXOSTRON_KEYS="$disk_dir/keys" NIX_DISK_IMAGE="$disk_dir/nixostron.qcow2" \
      setsid "$runner" </dev/null >"$state_dir/qemu.log" 2>&1 &
    echo $! >"$pid_file"
  )
  wait_for_ssh "$user"
  check_system

  log "rebooting"
  guest "$user" 'sudo reboot' || true
  sleep 10
  wait_for_ssh "$user"
  check_system

  if [ -n "$keep" ]; then
    log "keeping nixostron on localhost:$port (nixostron-vm ssh, nixostron-vm destroy)"
  else
    qemu_stop
    rm -rf "$disk_dir"
    log "$ref passed; nixostron deleted"
  fi
}

# --- Commands ---------------------------------------------------------------------

run_test() {
  local ref="" fresh="" disko="" keep="" arg
  for arg in "$@"; do
    case "$arg" in
      --fresh)
        require_tart --fresh
        fresh=1
        ;;
      --disko)
        [ "$backend" = "qemu" ] || die "--disko is only available on Linux (QEMU)"
        disko=1
        ;;
      --keep) keep=1 ;;
      -*) die "unknown option $arg" ;;
      *) ref="$arg" ;;
    esac
  done
  [ -n "$ref" ] || die "usage: nixostron-vm test <ref> [--fresh | --disko] [--keep]"
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || die "unknown ref $ref"
  mkdir -p "$state_dir"
  if [ "$backend" = "tart" ]; then
    tart_test "$ref" "$fresh" "$keep"
  else
    qemu_test "$ref" "$disko" "$keep"
  fi
}

case "${1:-}" in
  seed) build_seed ;;
  baseline)
    shift
    build_baseline "$@"
    ;;
  test)
    shift
    run_test "$@"
    ;;
  ssh)
    access_key
    if [ "$backend" = "tart" ]; then
      ip="$(tart ip "$test_vm")"
    fi
    guest "$user"
    ;;
  destroy)
    if [ "$backend" = "tart" ]; then
      tart stop "$test_vm" 2>/dev/null || true
      tart delete "$test_vm"
    else
      access_key
      qemu_stop
      rm -rf "$disk_dir"
    fi
    ;;
  *) die "usage: nixostron-vm seed | baseline [ref] | test <ref> [--fresh | --disko] [--keep] | ssh | destroy" ;;
esac
