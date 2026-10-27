# .github

Organization repository of Noosphaira. It holds the git rules for every repository in the organization, the checks that enforce them, and the files that each repository gets.

## Branch and pull request model

- `develop` is the integration branch and the default branch. `master` holds released code.
- Every change goes to `develop` through a pull request from a branch named `<category>/<description>`, for example `feature/csv-export`. Categories: `feature`, `bugfix`, `documentation`, `refactor`, `test`, `chore`.
- Pull requests to `develop` are squash-merged. Pull requests to `master` come from `develop` only, need an approval from the team `release-approvers`, and are merged with a merge commit.
- Nobody pushes to, force-pushes or deletes `develop` or `master`.

The full rules for agents and people are in the Universal section of `repo-files/AGENTS.md`.

## Contents

| Path | Contents |
|---|---|
| `pull_request_template.md` | Organization pull request template: Summary, Category, User review, Verification. A repository's own `.github/pull_request_template.md` takes precedence. |
| `.github/workflows/pr-policy.yml` | Policy checks for pull requests to `develop` and `master`: `branch-name`, `commit-messages`, `pr-size`. |
| `rulesets/develop.json`, `rulesets/master.json` | The organization rulesets "develop" and "master". |
| `rulesets/apply.sh` | Creates the rulesets through the API. |
| `repo-files/` | Files that every repository gets, at the paths they have in a repository. |
| `agent/gh-app-token` | Token script for the machines that run coding agents. |
| `AGENTS.md`, `.claude/`, `.githooks/` | This repository's own copy of the repository files. |

## Enforcement

| Layer | What it enforces |
|---|---|
| Organization rulesets | Pull request required on `develop` and `master`. No force push, no deletion. Merge methods. Resolved review threads. One approval from `release-approvers` on `master`. The `pr-policy` checks. |
| `pr-policy` workflow | Branch names, base and head of pull requests to `master`, commit trailers, pull request size (1,000 changed lines without lockfiles; the `size-exception` label allows more). |
| Git hooks in `.githooks/` | No commits or pushes to `develop` or `master`, branch names, commit subject length, commit trailers, no `CLAUDE.md` files. Each clone needs `git config core.hooksPath .githooks`. |
| `AGENTS.md` and the skills | The work cycle: user review before push, the review loop, and releases to `master` only when the user asks. |

The rulesets take `pr-policy.yml` from `master` in this repository. A change to the workflow applies after it is released to `master`. This repository is public because a ruleset can use a workflow from a private repository only in private repositories.

## Set up a repository

1. Create `develop` from `master` and make it the default branch. Allow squash merge and merge commits, turn off rebase merge, and turn on head branch deletion after merge.
2. On a branch from `develop`, copy the contents of `repo-files/` into the repository. Make the three hooks in `.githooks/` executable.
3. Fill the Project section of `AGENTS.md`.
4. Open a pull request to `develop`.
5. If the repository has CI, add a repository ruleset on `develop` and `master` that requires its CI checks.

## Change a rule

1. Change the file in this repository: `repo-files/` for the repository files, `pr-policy.yml` for the checks, `rulesets/` for the rulesets.
2. Merge the change into `develop`, then release it to `master`.
3. For a change in `repo-files/`, update each repository through a pull request. Replace only the Universal section of `AGENTS.md`, between the `BEGIN UNIVERSAL` and `END UNIVERSAL` comments. Keep the Project section.
4. For a change in `rulesets/`, update the live ruleset in the organization settings or through the API.

## Agent machines

Coding agents push and open pull requests as the GitHub App `noosphere-agent`. A pull request author cannot approve their own pull request, so this lets a person approve pull requests to `master`.

1. Copy `agent/gh-app-token` to `~/.local/bin/gh-app-token` and make it executable.
2. Put the App's private key at `~/.config/gh-app/private-key.pem` with mode 600.
3. Create `~/.config/gh-app/config` with `APP_ID`, `INSTALLATION_ID` and `PRIVATE_KEY`.
4. In `~/.claude/settings.json`, add a `SessionStart` hook that runs `"$HOME/.local/bin/gh-app-token" --env >> "$CLAUDE_ENV_FILE"`, and set `"attribution": { "commit": "", "pr": "" }`.
5. In a new Claude Code session, `gh api /installation/repositories --jq .total_count` prints the number of repositories the App can use.
