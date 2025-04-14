#!/bin/bash

changed() {
  echo "# ${FUNCNAME[0]} $*" >&2

  if [[ $# -ne 2 ]]; then
    echo "illegal number of parameters" >&2
    echo "Usage" >&2
    echo "  ./bin/changed.sh PATH_TO_CHECK ORIGIN" >&2
    echo "    PATH_TO_CHECK : Path to compare" >&2
    echo "    ORIGIN : Origin branch name to compare" >&2
  fi

  local PATH_TO_CHECK=${1-'PLEASE_DEFINE_PATH_TO_CHECK'}
  local ORIGIN=${2-'PLEASE_DEFINE_ORIGIN_BRANCH_TO_COMPARE'}

  local CHANGED

  echo "Path to check: ${PATH_TO_CHECK}" >&2
  echo "Origin: ${ORIGIN}" >&2

  CHANGED="$(git diff --name-only --no-color "origin/${ORIGIN}" -- "${PATH_TO_CHECK}")"

  if [ -z "$CHANGED" ]; then
    echo "There is no change for ${PATH_TO_CHECK} compared to ${ORIGIN}." >&2
    return 1
  else
    echo "${PATH_TO_CHECK} is changed" >&2
    return 0
  fi
}
