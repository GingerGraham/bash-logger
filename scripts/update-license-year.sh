#!/usr/bin/env bash
#
# update-license-year.sh - Keep the copyright year in LICENSE current.
#
# Rewrites the first "Copyright ... YYYY" line so the notice covers the
# current year. The first year never changes; only the end year moves forward:
#
#   Copyright © 2026 Name        ->  Copyright © 2026-2027 Name   (run in 2027)
#   Copyright © 2026-2027 Name   ->  Copyright © 2026-2028 Name   (run in 2028)
#
# A notice that already covers the current year is left untouched, so running
# the script more than once is safe.
#
# Usage: update-license-year.sh [<license-file>] [<year>]
#   <license-file>  Defaults to the LICENSE file at the repository root.
#   <year>          Four-digit year to bring the notice up to. Defaults to the
#                   current UTC year. Mainly useful for tests.
#
# Exit codes:
#   0  The file was updated, or was already current.
#   1  Invalid arguments, no copyright line found, or the notice starts in a
#      year later than <year>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LICENSE_FILE="${1:-$SCRIPT_DIR/../LICENSE}"
CURRENT_YEAR="${2:-$(date -u +%Y)}"

# Groups: 1 = text before the year, 2 = first year, 4 = existing end year
# (empty for a single-year notice), 5 = text after the years.
# Group 1 may not contain digits, so it stops at the first year even when the
# notice is already a range.
COPYRIGHT_PATTERN='^(Copyright[^0-9]*)([0-9]{4})(-([0-9]{4}))?(.*)$'

if [[ ! "$CURRENT_YEAR" =~ ^[0-9]{4}$ ]]; then
    echo "Error: year must be four digits, got '$CURRENT_YEAR'" >&2
    exit 1
fi

if [[ ! -f "$LICENSE_FILE" ]]; then
    echo "Error: license file not found: $LICENSE_FILE" >&2
    exit 1
fi

copyright_line=$(grep -m 1 -E "$COPYRIGHT_PATTERN" "$LICENSE_FILE" || true)
if [[ -z "$copyright_line" ]]; then
    echo "Error: no 'Copyright ... YYYY' line found in $LICENSE_FILE" >&2
    exit 1
fi

# The pattern is guaranteed to match because grep just found this line.
[[ "$copyright_line" =~ $COPYRIGHT_PATTERN ]]
text_before="${BASH_REMATCH[1]}"
first_year="${BASH_REMATCH[2]}"
end_year="${BASH_REMATCH[4]:-$first_year}"
text_after="${BASH_REMATCH[5]}"

# 10# forces base 10 so a year with a leading zero is not read as octal.
if (( 10#$first_year > 10#$CURRENT_YEAR )); then
    echo "Error: notice starts in $first_year, which is after $CURRENT_YEAR" >&2
    exit 1
fi

if (( 10#$end_year >= 10#$CURRENT_YEAR )); then
    echo "Copyright notice already covers $CURRENT_YEAR; nothing to do."
    exit 0
fi

new_line="${text_before}${first_year}-${CURRENT_YEAR}${text_after}"

# Read the file as one string. The trailing "x" stops command substitution from
# stripping a final newline, so the file is written back byte-for-byte (the
# LICENSE file has no trailing newline).
license_text=$(cat "$LICENSE_FILE"; printf x)
license_text="${license_text%x}"

# Quoting the search text makes this a literal match, not a glob pattern.
# Redirecting into the existing file keeps its permissions.
printf '%s' "${license_text/"$copyright_line"/"$new_line"}" > "$LICENSE_FILE"

echo "Updated copyright notice: $first_year-$CURRENT_YEAR"
