#!/bin/bash

npm run commit-and-tag-version -- --skip.commit --skip.tag -i RELEASE_NOTES.md

# shellcheck disable=SC2046 # intentional splitting
git checkout $(git diff --name-only | tr '\n' ' ')

RELEASE_NOTES="$(cat RELEASE_NOTES.md)"

if [[ "$CI" == "true" ]]; then
  {
    echo "RELEASE_NOTES<<EOF"
    echo "$RELEASE_NOTES"
    echo "EOF"
  } >>"$GITHUB_ENV"
fi

echo RELEASE_NOTES.md

rm RELEASE_NOTES.md
