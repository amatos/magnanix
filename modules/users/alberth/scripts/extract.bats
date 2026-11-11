#!/usr/bin/env bats
# Tests for extract.sh. Archives are built in a temporary directory.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/extract.sh"
  cd "$BATS_TEST_TMPDIR"
  mkdir src
  echo hello >src/file.txt
}

@test "extracts a .tar.gz" {
  tar -czf archive.tar.gz src
  rm -r src
  run sh "$SCRIPT" archive.tar.gz
  [ "$status" -eq 0 ]
  [ "$(cat src/file.txt)" = hello ]
}

@test "extracts a .tar" {
  tar -cf archive.tar src
  rm -r src
  run sh "$SCRIPT" archive.tar
  [ "$status" -eq 0 ]
  [ "$(cat src/file.txt)" = hello ]
}

@test "decompresses a .gz" {
  gzip src/file.txt
  run sh "$SCRIPT" src/file.txt.gz
  [ "$status" -eq 0 ]
  [ "$(cat src/file.txt)" = hello ]
}

@test "handles a file name with spaces" {
  tar -czf "my archive.tar.gz" src
  rm -r src
  run sh "$SCRIPT" "my archive.tar.gz"
  [ "$status" -eq 0 ]
  [ "$(cat src/file.txt)" = hello ]
}

@test "fails on an unknown extension" {
  run sh "$SCRIPT" src/file.txt
  [ "$status" -eq 1 ]
  [[ $output == *"'src/file.txt' cannot be extracted"* ]]
}

@test "fails on a missing file" {
  run sh "$SCRIPT" nope.tar.gz
  [ "$status" -eq 1 ]
  [[ $output == *"'nope.tar.gz' is not a valid file"* ]]
}

@test "prints usage without exactly one argument" {
  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ $output == *"Usage:"* ]]
}
