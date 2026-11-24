#!/usr/bin/env bash
# Sets up the organization's repositories that are not set up yet:
#   1. Creates master from develop, or develop from master, when one of them is missing.
#   2. Makes develop the default branch.
#   3. Opens a pull request to develop with the files in repo-files/.
# Repositories that are already set up are not changed. A repository that fails is reported, the run
# continues with the next repository and exits with status 1.
#
# Environment:
#   GH_TOKEN  Token of the noosphere-agent App (contents, pull requests, issues; administration for step 2).
#   ORG       Organization. Default: Noosphaira.
#   REPO      Optional. Only this repository.
#   DRY_RUN   1: report what would change, change nothing.
#   SUMMARY   Optional. File that receives a Markdown report (GITHUB_STEP_SUMMARY in Actions).
set -eo pipefail

ORG="${ORG:-Noosphaira}"
DRY_RUN="${DRY_RUN:-0}"
SUMMARY="${SUMMARY:-/dev/null}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILES="$ROOT/repo-files"
SETUP_BRANCH="chore/repository-setup"
BOT_NAME="noosphere-agent[bot]"
BOT_EMAIL="348749931+noosphere-agent[bot]@users.noreply.github.com"
SETTINGS_ISSUE="Repository settings need an administrator"

[ -n "$GH_TOKEN" ] || { echo "GH_TOKEN is not set." >&2; exit 1; }
[ -d "$FILES" ] || { echo "repo-files/ not found at $FILES." >&2; exit 1; }

report() {
  printf '%s\n' "$*"
  printf '%s\n' "$*" >> "$SUMMARY"
}

act() {
  if [ "$DRY_RUN" = 1 ]; then
    report "  - would: $1"
    return 1
  fi
  report "  - $1"
}

has_branch() {
  gh api "repos/$ORG/$1/git/ref/heads/$2" --silent 2>/dev/null
}

create_branch() {
  gh api "repos/$ORG/$1/git/refs" --method POST -f ref="refs/heads/$2" \
    -f sha="$(gh api "repos/$ORG/$1/git/ref/heads/$3" --jq .object.sha)" --silent
}

has_file() {
  gh api "repos/$ORG/$1/contents/$3?ref=$2" --silent 2>/dev/null
}

open_pull_request() {
  local repo="$1" work body
  work="$(mktemp -d)"
  git clone -q --depth 1 --branch develop \
    "https://x-access-token:$GH_TOKEN@github.com/$ORG/$repo.git" "$work/repo"
  git -C "$work/repo" switch -q -c "$SETUP_BRANCH"
  cp -R "$FILES/." "$work/repo/"
  chmod +x "$work/repo/.githooks/pre-commit" "$work/repo/.githooks/commit-msg" "$work/repo/.githooks/pre-push"
  git -C "$work/repo" add -A
  git -C "$work/repo" -c user.name="$BOT_NAME" -c user.email="$BOT_EMAIL" commit -q \
    -m "Add agent rules, git workflow skills and git hooks" \
    -m "Copy the organization's repository files from Noosphaira/.github repo-files/: AGENTS.md with the universal rules and an empty Project section, the git-workflow and pr-review-loop skills, and the git hooks in .githooks."
  git -C "$work/repo" push -q origin "$SETUP_BRANCH"
  body="$work/body.md"
  cat > "$body" <<'EOF'
## Summary
Add the organization's repository files from `Noosphaira/.github` `repo-files/`:
- `AGENTS.md` with the universal rules and an empty Project section.
- The `git-workflow` and `pr-review-loop` skills in `.claude/skills/`.
- The git hooks in `.githooks/`.

## Category
chore

## User review
Opened by the repository setup workflow in `Noosphaira/.github`. Not reviewed yet.

## Verification
- The files are copies of `repo-files/` in `Noosphaira/.github`.
- The Project section of `AGENTS.md` still has placeholders.
EOF
  gh pr create -R "$ORG/$repo" --base develop --head "$SETUP_BRANCH" \
    --title "Add agent rules, git workflow skills and git hooks" --body-file "$body" > /dev/null
  rm -rf "$work"
}

open_settings_issue() {
  local repo="$1" missing="$2" body
  [ "$(gh api "repos/$ORG/$repo" --jq .has_issues)" = true ] || return 0
  if gh issue list -R "$ORG/$repo" --state open --search "\"$SETTINGS_ISSUE\" in:title" --json number --jq 'length' | grep -qv '^0$'; then
    return 0
  fi
  body="The repository setup workflow in \`Noosphaira/.github\` could not change these settings, because the noosphere-agent App has no Administration permission. Set them in Settings > General:

$missing"
  gh issue create -R "$ORG/$repo" --title "$SETTINGS_ISSUE" --body "$body" > /dev/null
}

setup_repo() {
  local repo="$1" info default missing="" changed=0
  info="$(gh api "repos/$ORG/$repo")"
  default="$(jq -r .default_branch <<< "$info")"

  if [ "$(jq -r .archived <<< "$info")" = true ]; then
    return 0
  fi
  if [ "$(jq -r .size <<< "$info")" = 0 ] && ! has_branch "$repo" "$default"; then
    report "- **$repo**: empty repository. Skipped until it has a first commit on develop."
    return 0
  fi

  # 1. master and develop
  local from="" to=""
  if ! has_branch "$repo" master; then
    from=develop to=master
  elif ! has_branch "$repo" develop; then
    from=master to=develop
  fi
  if [ -n "$to" ]; then
    if ! has_branch "$repo" "$from"; then
      report "- **$repo**: no develop or master branch (default branch: $default). Rename it to develop, then run again."
      return 0
    fi
    [ "$changed" = 1 ] || report "- **$repo**:"
    changed=1
    if act "create $to from $from"; then
      create_branch "$repo" "$to" "$from"
    fi
  fi

  # 2. Default branch. The rulesets set the merge methods.
  if [ "$default" != develop ]; then
    [ "$changed" = 1 ] || report "- **$repo**:"
    changed=1
    if act "set develop as default branch"; then
      if ! gh api "repos/$ORG/$repo" --method PATCH -f default_branch=develop --silent 2>/dev/null; then
        missing="- Default branch: develop"
        report "  - not allowed: the App needs the Administration permission. Set the default branch to develop by hand."
        open_settings_issue "$repo" "$missing"
      fi
    fi
  fi

  # 3. Repository files through a pull request
  if ! has_file "$repo" develop .githooks/lib/common.sh 2>/dev/null && has_branch "$repo" develop; then
    if [ "$(gh pr list -R "$ORG/$repo" --head "$SETUP_BRANCH" --state open --json number --jq length)" = 0 ]; then
      [ "$changed" = 1 ] || report "- **$repo**:"
      changed=1
      if act "open a pull request to develop with repo-files/"; then
        open_pull_request "$repo"
      fi
    fi
  fi
}

report "### Repository setup ($( [ "$DRY_RUN" = 1 ] && echo "dry run" || echo "run" ))"
if [ -n "$REPO" ]; then
  repos="$REPO"
else
  repos="$(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[].name')"
fi
failed=""
for repo in $repos; do
  set +e
  (set -e; setup_repo "$repo")
  status=$?
  set -e
  if [ "$status" != 0 ]; then
    report "- **$repo**: failed with exit status $status. The run log shows the error."
    failed="$failed $repo"
  fi
done
if [ -n "$failed" ]; then
  report "Failed:$failed"
  exit 1
fi
report "Done."
