#!/usr/bin/env bash
#set -eo pipefail

# Delete all local tags and fetch all tags from origin
# shellcheck disable=SC2046
git tag -d $(git tag)
git fetch --quiet --tags

# Check if there will be at least one bullet item in the generated CHANGELOG.md
if ! npm run commit-and-tag-version -- --dry-run 2>/dev/null | grep '^\*' >/dev/null; then
  # No semantically relevant changes, no version bump or tag is needed. This
  # check also prevents an infinite loop in the build pipeline, since the new
  # "chore(release)" commit will not be semantically relevant.
  echo "No semantically relevant changes found."
  exit
fi

if [[ -n "$BUILD_AUTHOR" ]]; then
  git config user.name "$BUILD_AUTHOR"
fi

npm run commit-and-tag-version

if [[ "$CI" == "true" ]]; then
  # shellcheck disable=SC2086
  echo "version=$(jq -r '.version' <package.json)" >>$GITHUB_OUTPUT
fi
