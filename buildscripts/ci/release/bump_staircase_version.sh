#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Staircase version bumper for the Persian-Tuner fork.
#
# After every merged pull request a new public release is cut, and the
# version walks up in "staircase" fashion:
#
#   1.0.1, 1.0.2, 1.0.3, ... 1.0.9, 1.0.10, 1.1.0,
#   1.1.1, ... 1.1.10, 1.2.0, ...
#
# Rule: every release increments PATCH. Once PATCH reaches 10 the next
# release rolls over: MINOR is incremented by one and PATCH resets to 0
# (e.g. 1.0.10 -> 1.1.0).
#
# The latest version is determined from the newest existing tag that
# matches v<MAJOR>.<MINOR>.<PATCH> (no alpha/beta/rc suffix). When no such
# tag exists, the very first release version is 1.0.1.
#
# Output (one KEY=VALUE line per item, meant for $GITHUB_OUTPUT):
#   MAJOR / MINOR / PATCH / VERSION / TAG_NAME
#
# The script does NOT modify any files; the caller writes version.cmake.

o="$(basename "$0")"

((${BASH_VERSION%%.*} >= 4)) || { echo >&2 "$o: Error: Please upgrade Bash."; exit 1; }

set -euo pipefail

MAJOR=""
MINOR=""
PATCH=""

tag_re='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'

while IFS= read -r tag; do
    if [[ "${tag}" =~ ${tag_re} ]]; then
        t_major="${BASH_REMATCH[1]}"
        t_minor="${BASH_REMATCH[2]}"
        t_patch="${BASH_REMATCH[3]}"
        if [[ -z "${MAJOR}" \
           || "${t_major}" -gt "${MAJOR}" \
           || ( "${t_major}" -eq "${MAJOR}" && "${t_minor}" -gt "${MINOR}" ) \
           || ( "${t_major}" -eq "${MAJOR}" && "${t_minor}" -eq "${MINOR}" && "${t_patch}" -gt "${PATCH}" ) ]]; then
            MAJOR="${t_major}"
            MINOR="${t_minor}"
            PATCH="${t_patch}"
        fi
    fi
done < <(git tag --list 'v*' | sort --version-sort)

if [[ -z "${MAJOR}" ]]; then
    # No prior release tag -> start the staircase.
    MAJOR=1
    MINOR=0
    PATCH=0
fi

if (( PATCH >= 10 )); then
    # Staircase rollover: 1.0.10 -> 1.1.0
    MINOR=$(( MINOR + 1 ))
    PATCH=0
else
    PATCH=$(( PATCH + 1 ))
fi

VERSION="${MAJOR}.${MINOR}.${PATCH}"
TAG_NAME="v${VERSION}"

echo "MAJOR=${MAJOR}"
echo "MINOR=${MINOR}"
echo "PATCH=${PATCH}"
echo "VERSION=${VERSION}"
echo "TAG_NAME=${TAG_NAME}"

echo >&2 "$o: Next staircase release version is ${VERSION} (tag ${TAG_NAME})."
