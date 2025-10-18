#!/bin/bash
# ------------------------------------------------------------------------------
# Script Name:     generate_changelog.sh
#
# Description:     Generates a categorized changelog from git commit messages
#                  between a previous tag and the current HEAD. Outputs the
#                  formatted changelog to the GitHub Actions environment.
#
# Usage:           ./generate_changelog.sh [<previous_git_tag>]
#
# Requirements:
#   - git must be installed and in the system PATH
#   - Executed within a git repository with a valid tag history
#   - Environment must define GITHUB_ENV (typically provided in GitHub Actions)
#
# Behavior:
#   - Reads all commits between the given tag and HEAD
#   - Parses commit messages expecting a format like: [category] message
#   - Categorizes commits by their bracketed prefix (e.g., [ci], [framework])
#   - Commit messages are linked using the provided repository URL
#   - Outputs the changelog in a format suitable for use in GitHub Actions via $GITHUB_ENV
#
# Exit Codes:
#   - 0: Success
#   - Non-zero: Any failure due to missing arguments, git errors, or parsing issues
# ------------------------------------------------------------------------------
set -eo pipefail

GIT_REPO_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"

# Get commit messages with commit hash and raw message separated (falls back to all commits if none is provided)
previous_git_tag="${1}"

if [[ -z "${previous_git_tag}" ]]; then
	# No previous tag → get all commits
	commit_messages=$(git log --pretty=format:"%h%n%B%n---END---")
else
	# Get commits since previous tag
	commit_messages=$(git log "${previous_git_tag}"..HEAD --pretty=format:"%h%n%B%n---END---")
fi

declare -A categories
commit_hash=""
commit_message=""

# Process commits and categorize them
while IFS= read -r line; do
	if [[ "$line" == "---END---" ]]; then
		# Process the full commit message line by line
		while IFS= read -r msg_line; do
			if [[ "$msg_line" =~ ^\[([A-Za-z0-9_.-]+)\]\ (.+) ]]; then
				category="${BASH_REMATCH[1]}"
				message="${BASH_REMATCH[2]}"
				categories["${category}"]+="- [[${commit_hash}](${GIT_REPO_URL}/commit/${commit_hash})] ${message}"$'\n'
			fi
		done <<<"${commit_message}"

		# Reset for next commit
		commit_hash=""
		commit_message=""
	elif [[ -z "${commit_hash}" ]]; then
		commit_hash="${line}"
	else
		commit_message+="${line}"$'\n'
	fi
done <<<"${commit_messages}"

# Generate changelog content
changelog_content=$(mktemp)

{
	# Collect and sort all categories
	IFS=$'\n' && mapfile -t sorted < <(printf "%s\n" "${!categories[@]}" | sort) && unset IFS

	# Print all categories
	for cat in "${sorted[@]}"; do
		echo "**[${cat}]**"
		echo "${categories[$cat]}"
		echo ""
	done
} >>"${changelog_content}"

# Output changelog content
{
	echo "changelog_content<<EOF"
	cat "${changelog_content}"
	echo "EOF"
} >>"${GITHUB_ENV}"
