#!/usr/bin/env bats
# Tests for dollar.sh.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/dollar.sh"
}

@test "runs its arguments as a command" {
  run sh "$SCRIPT" echo "two  spaces"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Quit pasting in commands from the internet, you lazy bum." ]
  [ "${lines[1]}" = "two  spaces" ]
}

@test "passes the command's exit status through" {
  run sh "$SCRIPT" sh -c 'exit 3'
  [ "$status" -eq 3 ]
}
