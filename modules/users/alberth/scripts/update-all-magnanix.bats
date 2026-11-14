#!/usr/bin/env bats
# Tests for update-all-magnanix. Run with `test-scripts` (all script tests) or
# `bats modules/users/alberth/scripts/update-all-magnanix.bats`.
#
# ssh, deploy-magnanix, nix, sudo and hostname are stubs on PATH. The local
# host is "testlocal", and what a deploy does is picked by the host's name (see
# `behave` below). Every stub call is appended to $CALLS (newlines in arguments
# become spaces), and every host ssh reaches to $SSH_HOSTS.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/update-all-magnanix"
  export TEST_TMP="$BATS_TEST_TMPDIR"
  export CALLS="$TEST_TMP/calls"
  export SSH_HOSTS="$TEST_TMP/ssh-hosts"
  # The script's log directory goes here, so tests can see it kept or removed.
  export TMPDIR="$TEST_TMP"
  touch "$CALLS"

  stubs="$TEST_TMP/bin"
  mkdir -p "$stubs"
  PATH="$stubs:$PATH"

  # A deploy's behaviour, by host name.
  stub behave '
    case $1 in
      fail*) echo "building $1"; echo "error: build failed on $1" >&2; exit 1 ;;
      down*) echo "ssh: connect to host $1 port 22: Operation timed out" >&2; exit 255 ;;
      missing*) echo "zsh: command not found: deploy-magnanix" >&2; exit 127 ;;
      pair*)
        # Succeeds only if the other pair* host starts while this one runs.
        touch "$TEST_TMP/started-$1"
        for _ in $(seq 50); do
          [ "$(find "$TEST_TMP" -name "started-pair*" | wc -l)" -ge 2 ] && exit 0
          sleep 0.1
        done
        echo "$1 ran alone" >&2
        exit 1 ;;
      slow*)
        echo "$$" >"$TEST_TMP/slow.pid"
        echo started
        sleep 30 &
        echo "$!" >"$TEST_TMP/sleep.pid"
        wait
        echo finished ;;
      *) echo "building $1"; echo "switched $1" ;;
    esac'
  # ssh [options] host command: the host is the next-to-last argument.
  stub ssh 'echo "ssh $*" | tr "\n" " " | sed "s/ *\$//" >>"$CALLS"; echo >>"$CALLS"
    echo "${@: -2:1}" >>"$SSH_HOSTS"; behave "${@: -2:1}"'
  # nix build ... <flake>#nixosConfigurations.<host>.config...: prints the
  # host's made-up system path, or fails if NIX_STATUS is set.
  stub nix 'echo "nix $*" >>"$CALLS"
    if [ "${NIX_STATUS:-0}" -ne 0 ]; then echo "error: build failed" >&2; exit "$NIX_STATUS"; fi
    host=${*: -1}; host=${host#*nixosConfigurations.}; host=${host%%.*}
    echo "/nix/store/0000-nixos-system-$host"'
  stub deploy-magnanix 'echo "deploy-magnanix (local)" >>"$CALLS"; behave ok-local'
  stub sudo 'echo "sudo $*" >>"$CALLS"; exit "${SUDO_STATUS:-0}"'
  stub hostname 'echo TestLocal'
}

# stub NAME BODY: writes an executable NAME onto the stub PATH.
stub() {
  printf '#!%s\n%s\n' "$BASH" "$2" >"$stubs/$1"
  chmod +x "$stubs/$1"
}

logdirs() { find "$TMPDIR" -maxdepth 1 -name 'update-all-magnanix.*'; }

@test "deploys every host and exits 0 when all succeed" {
  run bash "$SCRIPT" ok-a ok-b
  [ "$status" -eq 0 ]
  [[ $output == *"[ok-a] switched ok-a"* ]]
  [[ $output == *"[ok-b] switched ok-b"* ]]
  [[ $output =~ ok-a\ +ok ]]
  [[ $output =~ ok-b\ +ok ]]
  # Logs are removed after a clean run.
  [ -z "$(logdirs)" ]
}

@test "uses non-interactive ssh that doesn't read stdin" {
  run bash "$SCRIPT" ok-a
  [ "$status" -eq 0 ]
  grep -qx "ssh -n -o BatchMode=yes -o ConnectTimeout=10 ok-a deploy-magnanix" "$CALLS"
}

@test "reports a failed host with the end of its log and keeps the logs" {
  run bash "$SCRIPT" ok-a fail-b
  [ "$status" -eq 1 ]
  [[ $output =~ ok-a\ +ok ]]
  [[ $output =~ fail-b\ +failed:\ exit\ status\ 1 ]]
  [[ $output == *"last lines from fail-b"* ]]
  [[ $output == *"    error: build failed on fail-b"* ]]
  [[ $output == *"1 of 2 hosts failed"* ]]
  grep -q "error: build failed on fail-b" "$(logdirs)/fail-b.log"
}

@test "explains ssh errors and a missing deploy-magnanix" {
  run bash "$SCRIPT" down-a missing-b
  [ "$status" -eq 1 ]
  [[ $output =~ down-a\ +failed:\ ssh\ error ]]
  [[ $output =~ missing-b\ +failed:\ deploy-magnanix\ not\ found ]]
  [[ $output == *"2 of 2 hosts failed"* ]]
}

@test "deploys the hosts in parallel" {
  run bash "$SCRIPT" pair-a pair-b
  [ "$status" -eq 0 ]
}

@test "runs the local host directly, after sudo -v, case-insensitively" {
  run bash "$SCRIPT" ok-a testlocal
  [ "$status" -eq 0 ]
  [[ $output == *"[testlocal] switched ok-local"* ]]
  ! grep -q "ssh .* testlocal " "$CALLS"
  # sudo -v comes before the local deploy.
  [ "$(grep -n -x "sudo -v" "$CALLS" | cut -d: -f1)" -lt \
    "$(grep -n -x "deploy-magnanix (local)" "$CALLS" | cut -d: -f1)" ]
}

@test "doesn't ask for sudo when the local host isn't deployed" {
  run bash "$SCRIPT" ok-a
  [ "$status" -eq 0 ]
  ! grep -q "^sudo" "$CALLS"
}

@test "deploys nothing if sudo fails" {
  SUDO_STATUS=1 run bash "$SCRIPT" ok-a testlocal
  [ "$status" -eq 1 ]
  [[ $output == *"sudo failed; can't deploy testlocal"* ]]
  ! grep -q -e "^ssh" -e "^deploy-magnanix" "$CALLS"
}

@test "on SIGTERM stops running deployments and reports them" {
  bash "$SCRIPT" slow-a ok-b >"$TEST_TMP/out" 2>&1 &
  pid=$!
  for _ in $(seq 50); do
    [ -s "$TEST_TMP/sleep.pid" ] && break
    sleep 0.1
  done
  [ -s "$TEST_TMP/sleep.pid" ]

  kill -TERM "$pid"
  status=0
  wait "$pid" || status=$?
  output=$(cat "$TEST_TMP/out")

  [ "$status" -eq 130 ]
  [[ $output =~ slow-a\ +failed:\ interrupted ]]
  [[ $output == *"interrupted; logs kept in"* ]]
  [[ $output != *"[slow-a] finished"* ]]
  # The stub and its child were stopped, not left running.
  ! kill -0 "$(cat "$TEST_TMP/slow.pid")" 2>/dev/null
  ! kill -0 "$(cat "$TEST_TMP/sleep.pid")" 2>/dev/null
}

@test "by default deploys every real host: all of modules/hosts except the VMs" {
  # Every real host must be in default_hosts; only the test VMs
  # (modules/hosts/virtual) and CI's ephemeral machines are left out.
  expected=$(find "$BATS_TEST_DIRNAME/../../../hosts" -mindepth 1 -maxdepth 1 -type d \
    ! -name virtual ! -name templates -exec basename {} \; | sort)
  [ -n "$expected" ]

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  actual=$(sort "$SSH_HOSTS")
  [ "$actual" = "$expected" ]
}

@test "builds tenabrae here from main and has it switch over ssh" {
  run bash "$SCRIPT" tenabrae
  [ "$status" -eq 0 ]
  grep -qx "nix build --refresh --no-link --print-out-paths github:amatos/magnanix#nixosConfigurations.tenabrae.config.system.build.toplevel" "$CALLS"
  [[ $output == *"[tenabrae] built /nix/store/0000-nixos-system-tenabrae"* ]]
  # One ssh session that waits for the cache, then sets the profile and switches.
  ssh_call=$(grep "^ssh " "$CALLS")
  [[ $ssh_call == "ssh -n -o BatchMode=yes -o ConnectTimeout=10 tenabrae "* ]]
  [[ $ssh_call == *"sudo nix-store --realise /nix/store/0000-nixos-system-tenabrae"* ]]
  [[ $ssh_call == *"sudo nix-env --profile /nix/var/nix/profiles/system --set /nix/store/0000-nixos-system-tenabrae"* ]]
  [[ $ssh_call == *"sudo /nix/store/0000-nixos-system-tenabrae/bin/switch-to-configuration switch"* ]]
  ! grep -q "deploy-magnanix" "$CALLS"
}

@test "doesn't switch tenabrae when its build fails" {
  NIX_STATUS=1 run bash "$SCRIPT" ok-a tenabrae
  [ "$status" -eq 1 ]
  [[ $output =~ ok-a\ +ok ]]
  [[ $output =~ tenabrae\ +failed:\ exit\ status\ 1 ]]
  [[ $output == *"    error: build failed"* ]]
  ! grep -q "^ssh .* tenabrae " "$CALLS"
}

@test "builds tenabrae here even when run on tenabrae" {
  stub hostname 'echo tenabrae'
  run bash "$SCRIPT" tenabrae
  [ "$status" -eq 0 ]
  grep -q "^nix build " "$CALLS"
  ! grep -q -e "^sudo" -e "deploy-magnanix" "$CALLS"
}
