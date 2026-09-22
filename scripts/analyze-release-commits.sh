#!/usr/bin/env bash
#
# analyze-release-commits.sh - Determine the release bump produced by commits
# since a given tag, restricted to commits that actually touch the
# deployable payload (logging.sh, workbench.yml).
#
# semantic-release's own commit-analyzer scans every commit since the last
# tag regardless of what files it touched, so a feat:/fix: commit that only
# changes CI config, tests, or docs still bumps the version. This script is
# used instead (via analyzeCommitsCmd in .releaserc.json, and by the manual
# workflow_dispatch pending-bump check in release.yml) so an in-scope commit
# has to touch a release-worthy path to move the version.
#
# The one exception is workflow_dispatch itself: its synthetic release commit
# is an empty commit (--allow-empty) created specifically to force a chosen
# bump level regardless of what changed, so path-filtering it would make
# manual dispatch unable to ever trigger a release. GITHUB_EVENT_NAME (set
# automatically by GitHub Actions) distinguishes the two cases.
#
# Usage: analyze-release-commits.sh [<last-tag>]
# Prints the highest release type found (major, minor, or patch) to stdout;
# prints nothing if no in-scope commit is release-worthy.

set -euo pipefail

LAST_TAG="${1:-}"
RELEASE_PATHS=(logging.sh workbench.yml)

if [[ -n "$LAST_TAG" ]]; then
    RANGE="$LAST_TAG..HEAD"
else
    RANGE="HEAD"
fi

if [[ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]]; then
    PENDING_LOG=$(git log "$RANGE" --pretty=%B)
else
    # A pathspec on git log filters the commit list itself, so only commits
    # that touched one of these paths contribute their message here.
    PENDING_LOG=$(git log "$RANGE" --pretty=%B -- "${RELEASE_PATHS[@]}")
fi

if echo "$PENDING_LOG" | grep -qE '^[a-z]+(\([^)]*\))?!:|^BREAKING[ -]CHANGE:'; then
    echo "major"
elif echo "$PENDING_LOG" | grep -qE '^feat(\([^)]*\))?:'; then
    echo "minor"
elif echo "$PENDING_LOG" | grep -qE '^(fix|perf|revert|refactor)(\([^)]*\))?:'; then
    echo "patch"
fi
