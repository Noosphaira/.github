#!/usr/bin/env bash
# Tests the git hooks in repo-files/.githooks in a temporary repository.
# Each case stages a change and expects the commit to pass or to be refused.
# Requirements: git, gitleaks.
set -eo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

cd "$WORK"
git init -q -b master
cp -R "$ROOT/repo-files/.githooks" .githooks
git config core.hooksPath .githooks
git config user.name "Hook test"
git config user.email "hook-test@example.com"
git -c core.hooksPath=/dev/null add -A
git -c core.hooksPath=/dev/null commit -q -m "Add the hooks"
git switch -q -c feature/hook-test

# expect <pass|refuse> <case name> <shell command that changes the working tree> [commit subject]
expect() {
  local want="$1" name="$2" change="$3" subject="${4:-Test $2}" got
  bash -c "$change"
  git add -A
  if git commit -q -m "$subject" > "$WORK/out.log" 2>&1; then got=pass; else got=refuse; fi
  if [ "$got" = "$want" ]; then
    echo "ok      $name: $got"
  else
    echo "FAILED  $name: expected $want, got $got"
    sed 's/^/        /' "$WORK/out.log"
    failures=$((failures + 1))
  fi
  git reset -q --hard HEAD
  git clean -q -f -d
}

expect pass   "clean change"        'echo hello > a.txt'
expect refuse "trailing whitespace" 'printf "x  \n" > b.txt'
expect refuse "conflict marker"     'printf "<<<<<<< HEAD\na\n=======\nb\n>>>>>>> other\n" > c.txt'
expect refuse "file over 5 MiB"     'head -c 6291456 /dev/urandom > big.bin'
expect pass   "file of 1 MiB"       'head -c 1048576 /dev/urandom > ok.bin'
# shellcheck disable=SC2016 # The command expands in the child shell.
expect refuse "secret"              'printf "token = \"ghp_%s\"\n" "$(head -c 400 /dev/urandom | tr -dc A-Za-z0-9 | cut -c1-36)" > d.txt'
expect refuse "CLAUDE.md file"      'echo rules > CLAUDE.md'
expect refuse "subject over 72"     'echo more >> a.txt' "Add a change whose subject line is far longer than the seventy-two character limit"
expect refuse "AI co-author trailer" 'echo more >> a.txt' "$(printf 'Add a change\n\nCo-authored-by: Claude <noreply@anthropic.com>')"

git switch -q master
expect refuse "commit on master"    'echo x > m.txt'

if [ "$failures" -gt 0 ]; then
  echo "$failures case(s) failed."
  exit 1
fi
echo "All cases passed."
