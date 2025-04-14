#!/usr/bin/env bash
# Constants
readonly TERRAGRUNT_CACHE_PATH=".terragrunt-cache"
readonly TERRAFORM_CACHE_PATH=".terraform"
readonly TERRAFORM_MAIN_FILE="main.tf"
readonly NO_CHANGES_MESSAGE="No Terraform directories to check."

# Initialize global variables
GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [[ -z $DEFAULT_BRANCH ]]; then
  DEFAULT_BRANCH="$(git remote show "$(git remote)" | grep 'HEAD branch' | cut -d ':' -f 2- | tr -d ' ')"
fi

if [[ ! -f "$SCRIPT_DIRECTORY/check_changed.sh" ]]; then
  echo "Error: 'check_changed.sh' file not found in the current directory."
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/check_changed.sh"

find_terraform_directories() {
  find . \
    -path "*/${TERRAGRUNT_CACHE_PATH}/*" -prune -o \
    -path "*/${TERRAFORM_CACHE_PATH}/*" -prune -o \
    -name "${TERRAFORM_MAIN_FILE}" -type f -print0 |
    xargs -0 -n1 dirname
}

process_terraform_directories() {
  local all_directories="$1"
  local changed_dirs=""

  if [ "$CHECK_CHANGED" == "false" ]; then
    echo "${all_directories}"
    return 0
  fi

  for terraform_dir in $all_directories; do
    if changed "$terraform_dir" "${DEFAULT_BRANCH}" 1>&2; then
      changed_dirs="${changed_dirs} ${terraform_dir}"
    fi
  done

  if [ -n "$changed_dirs" ]; then
    # shellcheck disable=SC2086
    echo $changed_dirs
  else
    echo "${NO_CHANGES_MESSAGE}" 1>&2
  fi
}

main() {
  (
    cd "${GIT_ROOT_DIRECTORY}" || exit 1

    local terraform_directories
    terraform_directories="$(find_terraform_directories)"

    if [ -n "${terraform_directories}" ]; then
      process_terraform_directories "${terraform_directories}"
    else
      echo "${NO_CHANGES_MESSAGE}" 1>&2
    fi
  )
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  main
fi
