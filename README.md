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
| `.github/workflows/pr-policy.yml` | Policy checks for pull requests to `develop` and `master` in every repository: `branch-name`, `commit-messages`, `pr-size`, `instruction-files`, `gitleaks`, `osv-scanner`, `zizmor`. |
| `.github/workflows/ci.yml`, `scripts/test-hooks.sh` | This repository's own format, lint and test: actionlint, shellcheck, and a test of the git hooks. |
| `rulesets/develop.json`, `rulesets/master.json` | The organization rulesets "develop" and "master". |
| `rulesets/apply.sh` | Creates the rulesets through the API. |
| `rulesets/repository-ci.json` | Repository ruleset "ci": requires the job `format, lint and test` on `develop` and `master`. Create it in a repository after its CI exists: `gh api repos/Noosphaira/<repository>/rulesets --method POST --input rulesets/repository-ci.json`. |
| `repo-files/` | Files that every repository gets, at the paths they have in a repository. |
| `.github/workflows/repository-setup.yml`, `scripts/setup-repos.sh` | Sets up new repositories automatically. See "Set up a repository". |
| `agent/gh-app-token` | Token script for the machines that run coding agents. |
| `AGENTS.md`, `.claude/`, `.githooks/` | This repository's own copy of the repository files. |

## Enforcement

| Layer | What it enforces |
|---|---|
| Organization rulesets | Pull request required on `develop` and `master`. No force push, no deletion. Merge methods. Resolved review threads. One approval from `release-approvers` on `master`. The `pr-policy` checks. |
| `pr-policy` workflow | `branch-name`: branch names, and pull requests to `master` only from `develop`. `commit-messages`: trailers, and subject lines of at most 72 characters in pull requests to `develop`. `pr-size`: 10,000 changed lines without lockfiles (the `size-exception` label allows more). `instruction-files`: no `CLAUDE.md` files. `gitleaks`: no secrets in the pull request's commits. `osv-scanner`: no dependency versions with known vulnerabilities that the base branch does not already have. `zizmor`: security audit of the repository's workflows. |
| Git hooks in `.githooks/` | No commits or pushes to `develop` or `master`, branch names, commit subject length, commit trailers, no `CLAUDE.md` files, no whitespace errors or conflict markers, no staged file over 5 MiB, no secrets (gitleaks on the staged changes). Each clone needs `git config core.hooksPath .githooks`, and the machine needs `gitleaks`. |
| Repository CI (`.github/workflows/ci.yml` in each repository) | The repository's format, lint and test, as the job `format, lint and test`. A repository ruleset on `develop` and `master` requires it. |
| `AGENTS.md` and the skills | The work cycle: user review before push, the review loop, and releases to `master` only when the user asks. |

The rulesets take `pr-policy.yml` from `master` in this repository. A change to the workflow applies after it is released to `master`. This repository is public because a ruleset can use a workflow from a private repository only in private repositories.

## Set up a repository

The `repository-setup` workflow runs every 15 minutes, as the `noosphere-agent` App. For each repository that is not set up yet, it:

1. Creates `develop` from `master`.
2. Makes `develop` the default branch and sets the merge settings. The App has no Administration permission, so GitHub refuses this step. The workflow then lists the settings in its run summary and opens the issue "Repository settings need an administrator" in the repository.
3. Opens a pull request from `chore/repository-setup` to `develop` with the files in `repo-files/`.

Then fill the Project section of `AGENTS.md` on that branch, and merge the pull request.

A new repository needs a first commit on `master` (create it with a README). Set the organization's default branch name for new repositories to `master`. An empty repository, or one without `master`, is reported and skipped.

To run the workflow at once: Actions > repository-setup > Run workflow. The inputs are a single repository and a dry run. Locally, with an App token in `GH_TOKEN`: `DRY_RUN=1 scripts/setup-repos.sh`.

Manual setup, the same steps:

1. Create `develop` from `master` and make it the default branch. Allow squash merge and merge commits, turn off rebase merge, and turn on head branch deletion after merge.
2. On a branch from `develop`, copy the contents of `repo-files/` into the repository. Make the three hooks in `.githooks/` executable.
3. Fill the Project section of `AGENTS.md`.
4. Open a pull request to `develop`.
5. Add `.github/workflows/ci.yml` with the job `format, lint and test`, then create the repository ruleset from `rulesets/repository-ci.json`.

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
