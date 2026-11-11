#!/usr/bin/env bats
# Tests for yubi-enable and yubi-disable. ykman and gpg-connect-agent are
# stubs on PATH.

setup() {
  export CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  stub "$BATS_TEST_TMPDIR/bin/ykman" 'echo "ykman $*" >>"$CALLS"; exit "${YKMAN_STATUS:-0}"'
  stub "$BATS_TEST_TMPDIR/bin/gpg-connect-agent" 'echo "gpg-connect-agent $*" >>"$CALLS"'
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

stub() {
  printf '#!%s\n%s\n' "$BASH" "$2" >"$1"
  chmod +x "$1"
}

@test "yubi-enable enables OpenPGP, then has gpg relearn the card" {
  run sh "$BATS_TEST_DIRNAME/yubi-enable"
  [ "$status" -eq 0 ]
  [[ $output == *"OpenPGP interface of YubiKey 32146072 enabled"* ]]
  [ "$(sed -n 1p "$CALLS")" = "ykman -d 32146072 config usb -e openpgp -f" ]
  [ "$(sed -n 2p "$CALLS")" = "gpg-connect-agent scd serialno learn --force /bye" ]
}

@test "yubi-enable fails without relearning if ykman fails" {
  YKMAN_STATUS=2 run sh "$BATS_TEST_DIRNAME/yubi-enable"
  [ "$status" -eq 1 ]
  [[ $output == *"ykman failed to enable OpenPGP"* ]]
  ! grep -q gpg-connect-agent "$CALLS"
}

@test "yubi-disable disables OpenPGP" {
  run sh "$BATS_TEST_DIRNAME/yubi-disable"
  [ "$status" -eq 0 ]
  [[ $output == *"OpenPGP interface of YubiKey 32146072 disabled"* ]]
  [ "$(cat "$CALLS")" = "ykman -d 32146072 config usb -d openpgp -f" ]
}

@test "yubi-disable fails if ykman fails" {
  YKMAN_STATUS=2 run sh "$BATS_TEST_DIRNAME/yubi-disable"
  [ "$status" -eq 1 ]
  [[ $output == *"ykman failed to disable OpenPGP"* ]]
}

@test "both fail when ykman isn't installed" {
  rm "$BATS_TEST_TMPDIR/bin/ykman"
  # Drop the rest of PATH so a real ykman can't be found.
  PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  run sh "$BATS_TEST_DIRNAME/yubi-enable"
  [ "$status" -eq 1 ]
  [[ $output == *"ykman not found"* ]]
  run sh "$BATS_TEST_DIRNAME/yubi-disable"
  [ "$status" -eq 1 ]
  [[ $output == *"ykman not found"* ]]
}
