#!/usr/bin/env bats
# Tests for control-dock.sh, with osascript stubbed on PATH.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/control-dock.sh"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir "$BATS_TEST_TMPDIR/bin"
  printf '#!%s\nprintf "%%s\\n" "$*" >>"$CALLS"\n' "$BASH" >"$BATS_TEST_TMPDIR/bin/osascript"
  chmod +x "$BATS_TEST_TMPDIR/bin/osascript"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "-h turns autohide on" {
  run sh "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = '-e tell application "System Events" to tell dock preferences to set autohide to true' ]
}

@test "-s turns autohide off" {
  run sh "$SCRIPT" -s
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = '-e tell application "System Events" to tell dock preferences to set autohide to false' ]
}

@test "prints usage and fails without options" {
  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ $output == *"Usage:"* ]]
  [ ! -e "$CALLS" ]
}

@test "prints usage and fails on an unknown option" {
  run sh "$SCRIPT" -x
  [ "$status" -eq 1 ]
  [[ $output == *"Usage:"* ]]
  [ ! -e "$CALLS" ]
}
