#!/usr/bin/env bash
#
# bootstrap-version.sh - Set initial version tag for semantic-release
#
# This script creates the initial v0.9.0 tag to bootstrap semantic-release.
# Run this once before enabling the release workflow.

set -e

CURRENT_VERSION="0.9.0"
TAG_NAME="${CURRENT_VERSION}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Bootstrap Initial Version Tag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "✗ Tag $TAG_NAME already exists"
    echo ""
    echo "To recreate the tag:"
    echo "  git tag -d $TAG_NAME"
    echo "  git push origin :refs/tags/$TAG_NAME"
    echo "  ./scripts/bootstrap-version.sh"
    exit 1
fi

# Create the tag
echo "Creating tag: $TAG_NAME"
git tag -a "$TAG_NAME" -m "chore(release): $CURRENT_VERSION

Initial release tag for semantic-release bootstrap.
This tag marks version $CURRENT_VERSION as documented in CHANGELOG.md."

echo "✓ Tag created locally"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Push the tag to GitHub:"
echo "   git push origin $TAG_NAME"
echo ""
echo "2. Commit the release configuration files:"
echo "   git add .releaserc.json .github/workflows/release.yml logging.sh scripts/bootstrap-version.sh"
echo "   git commit -m \"chore(ci): add semantic-release workflow\""
echo ""
echo "3. Push to main to trigger the release workflow:"
echo "   git push origin main"
echo ""
echo "4. Future releases will be automated based on commit messages:"
echo "   - feat: triggers minor version bump (0.9.0 → 0.10.0)"
echo "   - fix/perf/refactor: triggers patch version bump (0.9.0 → 0.9.1)"
echo "   - BREAKING CHANGE: triggers major version bump (0.9.0 → 1.0.0)"
echo ""
