#!/bin/bash
# ------------------------------------------------------------------------------
# Script Name:     bump_version.sh
#
# Description:     Increments the patch version from a given semantic version,
#                  updates the `VERSION` file, and stages and optionally commits changes.
#
# Usage:           ./bump_version.sh <current_version>
#
# Requirements:
#   - Bash 4+ with support for string manipulation and arrays
#   - Git repository initialized and containing a `VERSION` file and pom.xml files
#   - GitHub Actions environment variable `GITHUB_ENV` must be defined for CI integration
#
# Behavior:
#   - Parses the version string (e.g., 1.2.3), increments the patch number
#   - Writes the new version to the `VERSION` file
#   - Stages the updated files (`VERSION`)
#   - Commits the changes if any were made
#   - Outputs a GitHub Actions environment variable (`has_changes=true`) if changes were committed
#
# Exit Codes:
#   - 0: Success
#   - Non-zero: Failure due to invalid arguments or command errors
# ------------------------------------------------------------------------------

set -euo pipefail

current_version="${1}"

IFS='.' read -r major minor patch <<<"${current_version}"
new_patch=$((patch + 1))
next_version="${major}.${minor}.${new_patch}"

echo "Bumping version to ${next_version}"
echo "${next_version}" >VERSION

# Set Maven project version to next development SNAPSHOT version
mvn versions:set -DnewVersion="${next_version}-SNAPSHOT" -DgenerateBackupPoms=false -DprocessAllModules

# Push changes
git add -- VERSION pom.xml ./*/pom.xml

if git diff --cached --quiet; then
	echo "No changes to commit"
else
	git commit -m "[CI] Prepare next version: ${next_version}"
	echo "has_changes=true" >>"${GITHUB_ENV}"
fi
