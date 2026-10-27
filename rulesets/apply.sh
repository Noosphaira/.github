#!/usr/bin/env bash
# Creates the organization rulesets "develop" and "master" from the files in this folder.
# Run from the repository root. Needs a gh token with the admin:org scope.
# The files reference pr-policy.yml on master: a change to it applies after it is released to master.
set -eo pipefail

ORG=Noosphaira
REPO_ID=$(gh api "repos/$ORG/.github" --jq .id)
TEAM_ID=$(gh api "orgs/$ORG/teams/release-approvers" --jq .id)

for name in develop master; do
  jq --argjson repo "$REPO_ID" --argjson team "$TEAM_ID" '
    (.rules[] | select(.type == "workflows") | .parameters.workflows[].repository_id) = $repo
    | (.rules[] | select(.type == "pull_request") | .parameters.required_reviewers[]?.reviewer.id) = $team
  ' "rulesets/$name.json" | gh api "orgs/$ORG/rulesets" --method POST --input -
done
