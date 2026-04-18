#!/usr/bin/env bash
#
# create-issues.sh - Create GitHub issues from markdown issue files
#
# Reads YAML frontmatter (title, labels) from each markdown file and creates
# the corresponding GitHub issue using the gh CLI. The frontmatter block is
# stripped so only the issue body is submitted.
#
# Usage:
#   ./create-issues.sh [--dry-run] [--repo OWNER/REPO] [FILE...]
#
# If no files are given, all *.md files in the current directory are processed.
#
# Requirements:
#   - gh CLI installed and authenticated (gh auth login)
#   - Write access to the target repository
#
# Examples:
#   ./create-issues.sh                                    # all *.md in current dir
#   ./create-issues.sh BUG-*.md FEATURE-*.md DOCS-*.md   # specific files
#   ./create-issues.sh --dry-run *.md                     # preview without creating
#   ./create-issues.sh --repo GingerGraham/bash-logger BUG-01-*.md

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
DRY_RUN="false"
REPO=""           # empty = gh infers from current git remote
CREATED=0
SKIPPED=0
FAILED=0

# ── Helpers ───────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

log()  { printf '\e[34m[INFO]\e[0m  %s\n' "$*" >&2; }
ok()   { printf '\e[32m[OK]\e[0m    %s\n' "$*" >&2; }
warn() { printf '\e[33m[WARN]\e[0m  %s\n' "$*" >&2; }
err()  { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

# Extract a scalar value from YAML frontmatter: extract_fm_value "title" <file>
extract_fm_value() {
    local key="$1"
    local file="$2"
    # Match key: value between the opening and closing --- delimiters
    awk -v key="$key" '
        /^---$/ { if (in_fm) exit; in_fm=1; next }
        in_fm && $0 ~ "^"key":" {
            sub("^"key":[[:space:]]*", "")
            # Strip surrounding quotes if present
            gsub(/^["\x27]|["\x27]$/, "")
            print
            exit
        }
    ' "$file"
}

# Extract a list value from YAML frontmatter: extract_fm_list "labels" <file>
# Returns comma-separated values (gh --label accepts comma-separated string)
extract_fm_list() {
    local key="$1"
    local file="$2"
    awk -v key="$key" '
        /^---$/ { if (in_fm) exit; in_fm=1; next }
        in_fm && found {
            # List item line
            if (/^[[:space:]]+-[[:space:]]/) {
                sub(/^[[:space:]]+-[[:space:]]/, "")
                gsub(/^["\x27]|["\x27]$/, "")
                items = (items ? items "," : "") $0
                next
            }
            # Non-list line after key — stop
            exit
        }
        in_fm && $0 ~ "^"key":" {
            val = $0
            sub("^"key":[[:space:]]*", "", val)
            gsub(/^["\x27]|["\x27]$/, "", val)
            if (val != "") {
                # Inline value (e.g. labels: bug)
                items = val
                exit
            }
            found = 1
        }
        END { print items }
    ' "$file"
}

# Strip YAML frontmatter and return only the body content
strip_frontmatter() {
    local file="$1"
    awk '
        /^---$/ {
            if (!in_fm && !past_fm) { in_fm=1; next }
            if (in_fm)              { in_fm=0; past_fm=1; next }
        }
        past_fm { print }
    ' "$file"
}

# ── Argument parsing ──────────────────────────────────────────────────────────
FILES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)  DRY_RUN="true"; shift ;;
        --repo|-r)
            if [[ $# -lt 2 ]]; then
                err "Option $1 requires an argument."
                exit 1
            fi
            REPO="$2"
            shift 2
            ;;
        --help|-h)     usage ;;
        --)            shift; FILES+=("$@"); break ;;
        -*)            err "Unknown option: $1"; exit 1 ;;
        *)             FILES+=("$1"); shift ;;
    esac
done

# Default to all *.md in current directory if no files specified
if [[ ${#FILES[@]} -eq 0 ]]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find . -maxdepth 1 -name '*.md' | sort)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    err "No markdown files found."
    exit 1
fi

# ── Preflight checks ──────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
    err "gh CLI not found. Install it using your system package manager or see:"
    err "https://cli.github.com/"
    err "Then authenticate with: gh auth login"
    exit 1
fi

if [[ "$DRY_RUN" == "false" ]] && ! gh auth status >/dev/null 2>&1; then
    err "Not authenticated with gh. Run: gh auth login"
    exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
    warn "Dry-run mode — no issues will be created"
fi

# ── Process files ─────────────────────────────────────────────────────────────
TMPBODY=$(mktemp /tmp/issue-body-XXXXXX.md)
trap 'rm -f "$TMPBODY"' EXIT

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        warn "File not found, skipping: $file"
        ((SKIPPED++)) || true
        continue
    fi

    log "Processing: $file"

    # Parse frontmatter
    title=$(extract_fm_value "title" "$file")
    labels=$(extract_fm_list "labels" "$file")

    if [[ -z "$title" ]]; then
        warn "No 'title' found in frontmatter of $file — skipping"
        ((SKIPPED++)) || true
        continue
    fi

    # Write body (frontmatter stripped) to temp file
    strip_frontmatter "$file" > "$TMPBODY"

    # Build gh command
    gh_args=(issue create --title "$title" --body-file "$TMPBODY")

    if [[ -n "$labels" ]]; then
        # gh accepts comma-separated labels; split into multiple --label flags for safety
        IFS=',' read -ra label_arr <<< "$labels"
        for lbl in "${label_arr[@]}"; do
            lbl="${lbl#"${lbl%%[![:space:]]*}"}"   # trim leading whitespace
            lbl="${lbl%"${lbl##*[![:space:]]}"}"   # trim trailing whitespace
            [[ -n "$lbl" ]] && gh_args+=(--label "$lbl")
        done
    fi

    if [[ -n "$REPO" ]]; then
        gh_args+=(--repo "$REPO")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "  [DRY RUN] Would run: gh ${gh_args[*]}"
        warn "  [DRY RUN] Title:  $title"
        warn "  [DRY RUN] Labels: ${labels:-none}"
        ((CREATED++)) || true
        continue
    fi

    # Create the issue
    if issue_url=$(gh "${gh_args[@]}" 2>&1); then
        ok "  Created: $issue_url"
        ((CREATED++)) || true
    else
        err "  Failed to create issue for: $file"
        err "  gh output: $issue_url"
        ((FAILED++)) || true
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
printf '\e[1mSummary\e[0m\n'
printf '  %s %s\n' "$(printf '\e[32m✓\e[0m')" "Created:  $CREATED"
printf '  %s %s\n' "$(printf '\e[33m-\e[0m')" "Skipped:  $SKIPPED"
printf '  %s %s\n' "$(printf '\e[31m✗\e[0m')" "Failed:   $FAILED"

[[ "$FAILED" -gt 0 ]] && exit 1 || exit 0
