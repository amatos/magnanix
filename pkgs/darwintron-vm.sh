# Build and test the disposable darwintron Tart VM on magnus. Run from the repo
# inside `nix develop`:
#
#   darwintron-vm seed                 build darwintron-seed (macOS, Nix, ephemeral)
#   darwintron-vm baseline [ref]       build darwintron-baseline (seed + ref, default main)
#   darwintron-vm test <ref> [--fresh] [--keep]
#                                      switch a throwaway clone to ref. --fresh clones the
#                                      seed instead of the baseline; --keep keeps it on success
#   darwintron-vm ssh                  open a shell on the running darwintron
#   darwintron-vm destroy              stop and delete darwintron
#
# Neither image stores private keys: they are decrypted on magnus for each boot, piped
# in over SSH and removed again before an image is saved.

# Pinned so macOS only changes when this line does. macOS 27.2.
image="ghcr.io/cirruslabs/macos-golden-gate-vanilla@sha256:b35695ce30453bcc1db961a476740be72a44c2a2e464b73ece1ff0fcac12a873"
seed_vm="darwintron-seed"
baseline_vm="darwintron-baseline"
test_vm="darwintron"
user="ephemeral"
# Throwaway and non-secret: the VM is only reachable through magnus's NAT network.
password="ephemeral"
cpus=8
memory_mb=12288
disk_gb=100

repo="$(git rev-parse --show-toplevel)"
bootstrap="$repo/secrets/bootstrap/darwintron.yaml"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/darwintron-vm"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export SOPS_AGE_KEY_FILE="$HOME/.config/sops-nix/key.txt"

log() { printf '> %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

secret() {
  (umask 077 && sops -d --extract "[\"$1\"]" "$bootstrap" >"$work/$1")
}

# -F /dev/null skips the user's config, whose `*` rule points at the 1Password agent.
# Host keys aren't checked: the address is a local NAT lease and the key changes on injection.
guest() {
  local login="$1"
  shift
  ssh -F /dev/null -i "$work/access_key" -o IdentitiesOnly=yes -o IdentityAgent=none \
    -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR \
    -o ConnectTimeout=5 -o ServerAliveInterval=30 "$login@$ip" "$@"
}

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

wait_for_ssh() {
  local login="$1" _
  for _ in $(seq 1 90); do
    if guest "$login" true 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  die "SSH to $login@$ip did not come up"
}

# SSH comes up before the Nix daemon and the auto-login session that launchd agents need.
wait_for_session() {
  local _
  for _ in $(seq 1 90); do
    if guest "$user" "test -S /nix/var/nix/daemon-socket/socket && [ \"\$(stat -f %Su /dev/console)\" = $user ]" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  die "the Nix daemon or $user's login session did not come up"
}

shut_down() {
  log "shutting down $1"
  guest "$user" 'sudo shutdown -h now' || true
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

expected_recipient() {
  # Reads the checked-out .sops.yaml so a ref with different keys fails here, not mid-switch.
  grep -F "&$1 " "$work/src/.sops.yaml" | awk '{print $NF}'
}

inject_keys() {
  log "injecting keys"
  secret host_key
  secret host_key_pub
  secret user_key
  guest "$user" "sudo sh -c 'umask 077; cat > /etc/ssh/ssh_host_ed25519_key; chown root:wheel /etc/ssh/ssh_host_ed25519_key'" \
    <"$work/host_key"
  guest "$user" "sudo sh -c 'umask 022; cat > /etc/ssh/ssh_host_ed25519_key.pub'" <"$work/host_key_pub"
  guest "$user" 'umask 077; mkdir -p ~/.config/sops-nix; cat > ~/.config/sops-nix/key.txt' <"$work/user_key"
}

check_keys() {
  local host_age user_age
  host_age="$(guest "$user" 'sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key' | ssh-to-age)"
  user_age="$(guest "$user" 'cat ~/.config/sops-nix/key.txt' | age-keygen -y)"
  [ "$host_age" = "$(expected_recipient host_darwintron)" ] ||
    die "the guest's host key is not host_darwintron in .sops.yaml"
  [ "$user_age" = "$(expected_recipient ephemeral_darwintron)" ] ||
    die "the guest's user key is not ephemeral_darwintron in .sops.yaml"
  log "keys match .sops.yaml"
}

remove_keys() {
  # Decrypted secrets live on sops-nix's RAM disks, so they don't reach the saved image.
  # macOS generates a new, unrelated host key the next time sshd starts.
  log "removing keys"
  guest "$user" 'rm -f ~/.config/sops-nix/key.txt; sudo rm -f /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub'
}

send_source() {
  log "sending $1 ($(git rev-parse --short "$1"))"
  mkdir -p "$work/src"
  git archive "$1" | tar -x -C "$work/src"
  # A plain tree rather than a clone: vanilla macOS has no git until the Command Line
  # Tools are installed, and a path flake sees exactly what `git archive` wrote.
  tar -C "$work/src" -cf - . |
    guest "$user" 'rm -rf ~/Developer/magnanix; mkdir -p ~/Developer/magnanix; tar -xf - -C ~/Developer/magnanix'
}

apply() {
  log "applying configuration"
  # nix-darwin refuses to replace these on its first activation. This can't live in the
  # seed: Determinate's boot hook puts them back.
  guest "$user" 'for f in /etc/bashrc /etc/zshrc; do if [ -e "$f" ] && [ ! -L "$f" ]; then sudo mv "$f" "$f.before-nix-darwin"; fi; done'
  guest "$user" 'cd ~/Developer/magnanix && NIX_SENTRY_ENDPOINT="" /nix/var/nix/profiles/default/bin/nix develop --command apply-configuration'
}

check_canaries() {
  # Both are decrypted by launchd jobs, which may still be running just after a boot.
  local system_value home_value _
  for _ in $(seq 1 30); do
    system_value="$(guest "$user" 'sudo cat /run/secrets/canary' 2>/dev/null || true)"
    home_value="$(guest "$user" 'cat ~/.config/sops-nix/secrets/canary' 2>/dev/null || true)"
    if [ "$system_value" = "darwintron-system-canary" ] && [ "$home_value" = "ephemeral-home-canary" ]; then
      log "both canaries decrypted"
      return 0
    fi
    sleep 2
  done
  [ "$system_value" = "darwintron-system-canary" ] || die "system canary did not decrypt"
  die "Home Manager canary did not decrypt"
}

check_system() {
  check_canaries
  [ "$(guest "$user" 'dscl . -read /Users/ephemeral UserShell')" = "UserShell: /run/current-system/sw/bin/zsh" ] ||
    die "login shell is not Nix zsh"
  [ "$(guest "$user" 'scutil --get LocalHostName')" = "darwintron" ] || die "wrong hostname"
}

reboot_and_check() {
  log "rebooting"
  guest "$user" 'sudo shutdown -r now' || true
  sleep 15
  ip="$(tart ip --wait 180 "$test_vm")"
  wait_for_ssh "$user"
  wait_for_session
  check_system
}

build_seed() {
  vm_exists "$seed_vm" && die "$seed_vm exists; delete it first with: tart delete $seed_vm"
  secret access_key
  secret access_key_pub
  chmod 600 "$work/access_key"

  log "cloning $image"
  tart clone "$image" "$seed_vm"
  tart set "$seed_vm" --cpu "$cpus" --memory "$memory_mb" --disk-size "$disk_gb"
  boot "$seed_vm"

  log "installing the access key for admin"
  local _ up=""
  for _ in $(seq 1 90); do
    if SSHPASS="admin" sshpass -e ssh -F /dev/null -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=5 \
      -o PubkeyAuthentication=no "admin@$ip" \
      'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys' <"$work/access_key_pub" 2>/dev/null; then
      up=1
      break
    fi
    sleep 2
  done
  [ -n "$up" ] || die "SSH to admin@$ip did not come up"

  log "setting the hostname"
  guest admin 'for n in HostName LocalHostName ComputerName; do sudo scutil --set "$n" darwintron; done'

  log "creating $user"
  guest admin "sudo sysadminctl -addUser $user -fullName 'Ephemeral test user' -password $password -admin"
  # `sysadminctl -autologin` fails here (SACSetAutoLoginPassword error 22) and leaves the
  # image's password for admin in place. This is "$password" in kcpassword's XOR encoding.
  guest admin "echo 18f93a46bfd9af8bcfb91f7d | xxd -r -p | sudo tee /etc/kcpassword >/dev/null; sudo chmod 600 /etc/kcpassword; sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser $user"
  guest admin "echo '$user ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/$user >/dev/null; sudo chmod 440 /etc/sudoers.d/$user; sudo createhomedir -c -u $user >/dev/null 2>&1 || true"
  guest admin "sudo sh -c 'umask 077; mkdir -p /Users/$user/.ssh; cat > /Users/$user/.ssh/authorized_keys; chown -R $user:staff /Users/$user/.ssh'" \
    <"$work/access_key_pub"

  log "installing Determinate Nix"
  guest admin 'curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm'

  # Reboot so auto-login puts ephemeral in a GUI session, then confirm before saving.
  guest admin 'sudo shutdown -r now' || true
  sleep 15
  ip="$(tart ip --wait 180 "$seed_vm")"
  wait_for_ssh "$user"
  wait_for_session
  shut_down "$seed_vm"
  log "$seed_vm is ready"
}

build_baseline() {
  local ref="${1:-main}"
  vm_exists "$seed_vm" || die "$seed_vm does not exist; run: darwintron-vm seed"
  vm_exists "$baseline_vm" && die "$baseline_vm exists; delete it first with: tart delete $baseline_vm"
  secret access_key
  chmod 600 "$work/access_key"

  tart clone "$seed_vm" "$baseline_vm"
  boot "$baseline_vm"
  wait_for_ssh "$user"
  wait_for_session
  send_source "$ref"
  inject_keys
  check_keys
  apply
  check_system
  remove_keys
  shut_down "$baseline_vm"
  mkdir -p "$state_dir"
  git rev-parse "$ref" >"$state_dir/baseline-rev"
  log "$baseline_vm is ready at $ref"
}

run_test() {
  local ref="" from="$baseline_vm" keep="" arg previous current
  for arg in "$@"; do
    case "$arg" in
      --fresh) from="$seed_vm" ;;
      --keep) keep=1 ;;
      -*) die "unknown option $arg" ;;
      *) ref="$arg" ;;
    esac
  done
  [ -n "$ref" ] || die "usage: darwintron-vm test <ref> [--fresh] [--keep]"
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || die "unknown ref $ref"
  vm_exists "$from" || die "$from does not exist"
  vm_exists "$test_vm" && die "$test_vm exists; inspect it or run: darwintron-vm destroy"
  if [ "$from" = "$baseline_vm" ] && [ "$(cat "$state_dir/baseline-rev" 2>/dev/null)" != "$(git rev-parse main)" ]; then
    log "warning: $baseline_vm was not built from the current main"
  fi
  secret access_key
  chmod 600 "$work/access_key"

  tart clone "$from" "$test_vm"
  boot "$test_vm"
  wait_for_ssh "$user"
  wait_for_session
  send_source "$ref"
  inject_keys
  check_keys
  previous="$(guest "$user" 'readlink /nix/var/nix/profiles/system || true')"
  apply
  check_system
  current="$(guest "$user" 'readlink -f /run/current-system')"
  if [ -n "$previous" ]; then
    previous="$(guest "$user" "readlink -f /nix/var/nix/profiles/$previous")"
    guest "$user" "/etc/profiles/per-user/$user/bin/nvd diff $previous $current" || true
  fi
  reboot_and_check
  if [ -n "$previous" ]; then
    log "rolling back"
    guest "$user" 'sudo /run/current-system/sw/bin/darwin-rebuild --rollback'
    [ "$(guest "$user" 'readlink -f /run/current-system')" = "$previous" ] || die "rollback did not restore the previous system"
    log "rollback restored the previous system"
  fi
  if [ -n "$keep" ]; then
    log "keeping $test_vm at $ip (darwintron-vm ssh, darwintron-vm destroy)"
  else
    tart stop "$test_vm"
    tart delete "$test_vm"
    log "$ref passed; $test_vm deleted"
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
    secret access_key
    chmod 600 "$work/access_key"
    ip="$(tart ip "$test_vm")"
    guest "$user"
    ;;
  destroy)
    tart stop "$test_vm" 2>/dev/null || true
    tart delete "$test_vm"
    ;;
  *) die "usage: darwintron-vm seed | baseline [ref] | test <ref> [--fresh] [--keep] | ssh | destroy" ;;
esac
