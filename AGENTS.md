# AGENTS.md

<!-- BEGIN UNIVERSAL: maintained in the rules repository and synced. Edit it there. -->
## Universal rules

### Instruction files
- Do not create `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in any directory of this repository. Put instructions in AGENTS.md.
- Do not edit the Universal rules section (between the BEGIN UNIVERSAL and END UNIVERSAL comments). Project instructions go in the Project section.
- The Project section adds to the universal rules. A deviation is listed under "Exceptions to universal rules" and names the rule it changes.

### Setup
- Before the first commit in a session, run `git config core.hooksPath`. If the output is not `.githooks`, run `git config core.hooksPath .githooks`.
- Push, open pull requests and merge as the GitHub App `noosphere-agent`. The SessionStart hook sets `GH_TOKEN` to the App's token. Before the first push in a session, run `gh api /installation/repositories --silent`. If it fails, stop and report a blocker. Do not push with the user's credentials.

### Branches
- `master` holds released code. `develop` is the integration branch and the default branch.
- Never commit to `develop` or `master`, push to them, or rewrite their history.
- Create every new branch from the latest `origin/develop`.
- Branch name: `<category>/<description>`, lowercase, words separated by hyphens. Example: `feature/csv-export`.

| Category | Contents |
|---|---|
| `feature` | New functionality, or a change to existing functionality |
| `bugfix` | Fix for a defect |
| `documentation` | Changes to documentation only |
| `refactor` | Code restructuring with no change in behavior |
| `test` | Changes to tests only |
| `chore` | Dependency updates, build, CI and tooling configuration |

### Commits
- Subject line: imperative mood, at most 72 characters. Then a blank line and a body stating what changed and why.
- A commit with AI-generated changes ends with the trailer `Assisted-by: <agent>:<model>`. Example: `Assisted-by: claude-code:claude-opus-5-5`.
- No `Co-authored-by` or `Signed-off-by` trailer names an AI agent.
- Never run git with `--no-verify`.
- After a pull request is opened, do not rewrite the branch history. To update the branch, merge `origin/develop` into it.

### Work cycle
1. Create a branch from `develop`, implement the change, verify it.
2. Work is ready for user review when a person can use the change in its interface: a changed screen in the frontend, a command that runs in the terminal, an endpoint that responds. Code that compiles does not meet this.
3. Work with an open decision or blocker is not ready for user review. Present each decision and blocker to the user and wait for the answer.
4. When the work is ready: commit, run the change locally (Project > Run locally) and present it to the user. Do not push and do not open a pull request.
5. After the user approves: push the branch, open a pull request to `develop`, and follow the `pr-review-loop` skill until the pull request is merged.
   Every merge into `develop` is made as the App. A pull request that is ready to merge is not left open: merge it, or tell the user what it waits for. When the user wants to merge a pull request into `develop` with their own account, tell them first that they then cannot approve the next release pull request to `master`: the `master` ruleset requires an approval from someone other than the last pusher.
6. After the merge: open or update the pull request from `develop` to `master`. Merging into `master` requires the user's approval on GitHub. Merge into `master` only when the user asks.

The `git-workflow` skill contains the commands for each step.

### Verification
- Before user review, run the build, tests and linters listed in Project > Build, test and lint. The change adds no new warnings.
- Reproduce a bug before fixing it. Where the project has tests, add a test that fails without the fix.
- State what could not be built, run or tested.

### Change size
- Stop and ask the user before a change exceeds 1,000 added plus deleted lines, excluding lockfiles.
- A pull request to `develop` over this limit fails the `pr-size` check unless it has the `size-exception` label. Add the label only after the user approves the size.
<!-- END UNIVERSAL -->

## Project

### Overview
The organization's `.github` repository. GitHub uses its files as defaults for every repository in the Noosphaira organization.
- `pull_request_template.md` is the default pull request template. A repository's own `.github/pull_request_template.md` takes precedence.
- `.github/workflows/pr-policy.yml` holds the pull request policy checks: `branch-name`, `commit-messages` and `pr-size`. The organization rulesets "develop" and "master" require them.

### Build, test and lint
`.github/workflows/ci.yml` runs these on every pull request. Run them locally before user review:
- `docker run --rm -v "$PWD:/repo:ro" -w /repo rhysd/actionlint:1.7.12 -no-color`: lints the workflows.
- shellcheck on the hooks and scripts: the command in `.github/workflows/ci.yml`.
- `scripts/test-hooks.sh`: tests the git hooks in `repo-files/` in a temporary repository. Needs `gitleaks`.
- `uvx zizmor==1.31.1 .github/` with `GH_TOKEN` set: the audit that `pr-policy` runs on every repository.
- `scripts/setup-repos.sh`: before a change is merged, run it with `DRY_RUN=1` and an App token. It must report no change for repositories that are set up.

### Run locally
No application exists. To review a change to `pr-policy.yml` or the template, open a test pull request in `experiment-repo` after the change is merged, and show the check results or the pull request body.

### Repository layout
- `pull_request_template.md`: default pull request template.
- `.github/workflows/pr-policy.yml`: policy checks for pull requests to `develop` and `master`.
- `rulesets/develop.json`, `rulesets/master.json`: the organization rulesets for `develop` and `master`. IDs are filled in by `rulesets/apply.sh`.
- `rulesets/apply.sh`: creates the rulesets in the organization (needs the `admin:org` scope).
- `repo-files/`: the files every repository gets, at their repository paths. `AGENTS.md` there is the template with Project placeholders.
- `agent/gh-app-token`: token script for agent machines.
- `.github/workflows/repository-setup.yml`: runs `scripts/setup-repos.sh` every 15 minutes as the `noosphere-agent` App. App ID: variable `NOOSPHERE_AGENT_APP_ID`. Private key: secret `NOOSPHERE_AGENT_PRIVATE_KEY`.
- `scripts/setup-repos.sh`: sets up repositories that are not set up. `DRY_RUN=1` reports without changes.
- `README.md`: the git model, the contents of this repository, and how to set up a repository or change a rule.

### Conventions
- The live organization rulesets match the files in `rulesets/`. After a change to a file, update the live ruleset in the organization settings or through the API, in the same change.
- The rulesets take `pr-policy.yml` from `master`. A change to the workflow applies after it is released to `master`.
- This repository's own `AGENTS.md` Universal section, `.claude/skills/` and `.githooks/` are identical to `repo-files/`. Change both together.
- A rule in `pr-policy.yml` that is also in `.githooks/lib/common.sh` (branch pattern, `Assisted-by` pattern, AI identity pattern, lockfile list) changes in both places.

### Exceptions to universal rules
None.
