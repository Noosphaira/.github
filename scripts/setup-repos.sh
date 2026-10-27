#!/usr/bin/env bash
# Sets up the organization's repositories that are not set up yet:
#   1. Creates develop from master.
#   2. Makes develop the default branch and sets the merge settings.
#   3. Opens a pull request to develop with the files in repo-files/.
# Repositories that are already set up are not changed.
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

Before merging, fill the Project section of `AGENTS.md` on this branch.

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
    report "- **$repo**: empty repository. Skipped until it has a first commit on master."
    return 0
  fi

  # 1. develop from master
  if ! has_branch "$repo" develop; then
    if ! has_branch "$repo" master; then
      report "- **$repo**: no master branch (default branch: $default). Rename it to master, then run again."
      return 0
    fi
    [ "$changed" = 1 ] || report "- **$repo**:"
    changed=1
    if act "create develop from master"; then
      gh api "repos/$ORG/$repo/git/refs" --method POST -f ref=refs/heads/develop \
        -f sha="$(gh api "repos/$ORG/$repo/git/ref/heads/master" --jq .object.sha)" --silent
    fi
  fi

  # 2. Default branch and merge settings
  local want='{"default_branch":"develop","allow_squash_merge":true,"allow_merge_commit":true,"allow_rebase_merge":false,"delete_branch_on_merge":true}'
  if [ "$(jq -c '{default_branch, allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge}' <<< "$info")" != "$want" ]; then
    [ "$changed" = 1 ] || report "- **$repo**:"
    changed=1
    if act "set develop as default branch and the merge settings"; then
      if ! gh api "repos/$ORG/$repo" --method PATCH --input - --silent <<< "$want" 2>/dev/null; then
        missing="- Default branch: develop
- Allow merge commits and squash merging; do not allow rebase merging
- Automatically delete head branches"
        report "  - not allowed: the App needs the Administration permission. Settings to set by hand:"
        report "    ${missing//$'\n'/$'\n'    }"
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
for repo in $repos; do
  setup_repo "$repo"
done
report "Done."
