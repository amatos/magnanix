# Lints and tests the repo's shell and Python scripts. Packaged as `test-scripts`
# in the dev shell, and run by the `script-tests` flake check (CI).
#
# Usage: test-scripts [repo-dir]   (default: the git checkout you're in)
#
# Finds its targets itself, so new scripts and tests are picked up without
# registering them anywhere:
#   - shellcheck: every file whose shebang is sh or bash, plus pkgs/*.sh (bash
#     bodies of writeShellApplication, which adds `set -euo pipefail` itself, so
#     SC2164 (unchecked cd) doesn't apply; SC2016 is excluded as in outputs.nix)
#   - bats: every *.bats file
#   - Python: every test_*.py file, run with `python3 -I`; ruff check and
#     ruff format --check on every *.py file (default rules, ignoring any
#     personal ruff config, so local runs match CI)
#   - zsh: every file whose shebang is zsh gets `zsh -n` (a syntax check only;
#     zsh isn't supported by shellcheck, so prefer sh or bash for new scripts)
#
# Runs every section even after one fails, and exits 1 if any failed.

root=${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
cd "$root"

# Bytecode caches would land in the read-only source in the flake check.
export PYTHONDONTWRITEBYTECODE=1

failed=()

section() { printf '\n==> %s\n' "$1"; }

run() {
  local name=$1
  shift
  if "$@"; then
    echo "ok: $name"
  else
    echo "FAILED: $name"
    failed+=("$name")
  fi
}

# Every regular file outside .git; result* symlinks aren't followed.
mapfile -d '' files < <(find . -path ./.git -prune -o -type f -print0 | sort -z)

shell_scripts=()
zsh_scripts=()
bats_files=()
python_tests=()
python_files=()
for f in "${files[@]}"; do
  case $f in
    *.bats) bats_files+=("$f") ;;
    */test_*.py) python_tests+=("$f") ;;
  esac
  case $f in
    *.py) python_files+=("$f") ;;
    *)
      first=
      IFS= read -r first <"$f" 2>/dev/null || true
      if [[ $first =~ ^\#!\ ?(/usr/bin/env\ +|/bin/|/usr/bin/)(ba)?sh(\ |$) ]]; then
        shell_scripts+=("$f")
      elif [[ $first =~ ^\#!\ ?(/usr/bin/env\ +|/bin/|/usr/bin/)zsh(\ |$) ]]; then
        zsh_scripts+=("$f")
      fi
      ;;
  esac
done
pkg_scripts=(pkgs/*.sh)

section "shellcheck (${#shell_scripts[@]} scripts, ${#pkg_scripts[@]} in pkgs/)"
if [ ${#shell_scripts[@]} -gt 0 ]; then
  run shellcheck shellcheck "${shell_scripts[@]}"
fi
run "shellcheck pkgs/*.sh" shellcheck --shell=bash --exclude=SC2016,SC2164 "${pkg_scripts[@]}"

section "zsh -n (${#zsh_scripts[@]} scripts)"
for z in "${zsh_scripts[@]}"; do
  run "zsh -n $z" zsh -n "$z"
done

section "bats (${#bats_files[@]} files)"
if [ ${#bats_files[@]} -gt 0 ]; then
  run bats bats "${bats_files[@]}"
fi

section "Python tests (${#python_tests[@]} files)"
for t in "${python_tests[@]}"; do
  run "$t" python3 -I "$t"
done

section "ruff (${#python_files[@]} files)"
if [ ${#python_files[@]} -gt 0 ]; then
  run "ruff check" ruff check --isolated --no-cache "${python_files[@]}"
  run "ruff format" ruff format --isolated --no-cache --check "${python_files[@]}"
fi

echo
if [ ${#failed[@]} -gt 0 ]; then
  echo "test-scripts: ${#failed[@]} failed: ${failed[*]}"
  exit 1
fi
echo "test-scripts: all passed"
