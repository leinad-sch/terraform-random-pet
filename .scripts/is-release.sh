#!/bin/bash

# Check if there will be at least one bullet item in the generated CHANGELOG.md
if ! npm run commit-and-tag-version -- --dry-run | grep -q '^\*' >/dev/null; then
  # No semantically relevant changes, no version bump or tag is needed. This
  # check also prevents an infinite loop in the build pipeline, since the new
  # "chore(release)" commit will not be semantically relevant.
  echo "No semantically relevant changes found."
  if [[ "$CI" == "true" ]]; then
    # shellcheck disable=SC2086
    echo "RELEASE=false" >>$GITHUB_OUTPUT
  fi
else
  echo "Semantically relevant changes found."
  if [[ "$CI" == "true" ]]; then
    # shellcheck disable=SC2086
    echo "RELEASE=true" >>$GITHUB_OUTPUT
  fi
fi
