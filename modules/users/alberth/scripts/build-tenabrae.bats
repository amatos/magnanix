#!/usr/bin/env bats
# Tests for build-tenabrae. Run with `test-scripts` (all script tests) or
# `bats modules/users/alberth/scripts/build-tenabrae.bats`.
#
# nix is a stub on PATH that records its arguments, one per line, in $CALLS
# and prints a made-up store path.

# `run --separate-stderr` needs bats 1.5.
bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/build-tenabrae"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/work"
  printf '#!%s\nprintf "%%s\\n" "$@" >"$CALLS"\necho /nix/store/0000-tenabrae\nexit "${NIX_STATUS:-0}"\n' \
    "$BASH" >"$BATS_TEST_TMPDIR/bin/nix"
  chmod +x "$BATS_TEST_TMPDIR/bin/nix"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$BATS_TEST_TMPDIR/work"
}

# The arguments nix was called with, space-separated.
nix_args() { paste -sd ' ' "$CALLS"; }

@test "builds the system from the current directory's flake" {
  touch flake.nix
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(nix_args)" = "build --no-link --print-out-paths .#nixosConfigurations.tenabrae.config.system.build.toplevel" ]
  # Only the store path goes to stdout.
  [ "$output" = /nix/store/0000-tenabrae ]
}

@test "falls back to ~/Developer/magnanix outside a flake" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$CALLS")" = "$HOME/Developer/magnanix#nixosConfigurations.tenabrae.config.system.build.toplevel" ]
}

@test "builds the SD image from a given flake" {
  run bash "$SCRIPT" --sd-image github:amatos/magnanix
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$CALLS")" = "github:amatos/magnanix#nixosConfigurations.tenabrae.config.system.build.sdImage" ]
}

@test "passes options after -- to nix build" {
  run bash "$SCRIPT" . -- --max-jobs 0
  [ "$status" -eq 0 ]
  [ "$(nix_args)" = "build --no-link --print-out-paths --max-jobs 0 .#nixosConfigurations.tenabrae.config.system.build.toplevel" ]
}

@test "fails when the build fails" {
  NIX_STATUS=1 run bash "$SCRIPT" .
  [ "$status" -eq 1 ]
}

@test "rejects an unknown option and a second flake, with usage" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 1 ]
  [[ $output == *"unknown option --bogus"* ]]
  [[ $output == *"Usage: build-tenabrae"* ]]
  [ ! -e "$CALLS" ]

  run bash "$SCRIPT" . other
  [ "$status" -eq 1 ]
  [[ $output == *"more than one flake given"* ]]
}

@test "--help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ $output == *"Usage: build-tenabrae [--sd-image] [flake]"* ]]
  [[ $output == *"--sd-image"* ]]
}
