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
   Every merge into `develop` is made as the App. A pull request that is ready to merge is not left open: merge it, or tell the user what it waits for.
6. After the merge: open or update the pull request from `develop` to `master`. Merging into `master` requires the user's approval on GitHub. Merge into `master` only when the user asks.

The `git-workflow` skill contains the commands for each step.

### Verification
- Before user review, run the build, tests and linters listed in Project > Build, test and lint. The change adds no new warnings.
- Reproduce a bug before fixing it. Where the project has tests, add a test that fails without the fix.
- State what could not be built, run or tested.

### Change size
- Stop and ask the user before a change exceeds 10,000 added plus deleted lines, excluding lockfiles.
- A pull request to `develop` over this limit fails the `pr-size` check unless it has the `size-exception` label. Add the label only after the user approves the size.
<!-- END UNIVERSAL -->

## Project

### Overview
[Placeholder: what the repository contains, its main components and runtime.]

### Build, test and lint
[Placeholder: exact commands.]

### Run locally
[Placeholder: command that starts the change for user review, and the URL, port or command the user opens.]

### Repository layout
[Placeholder]

### Conventions
[Placeholder]

### Exceptions to universal rules
[Placeholder: `<rule>`: `<exception and scope>`. Empty when there are none.]
