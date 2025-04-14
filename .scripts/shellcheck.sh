#!/bin/bash

# Constants
readonly DOCKER_IMAGE="koalaman/shellcheck-alpine:latest"
readonly EXCLUDED_DIRS=(
  '.git'
  '.terragrunt-cache'
  '.terraform'
  'node_modules'
  '.peru'
  '.peru-deps'
)
MAX_PARALLEL_JOBS=$(nproc 2>/dev/null || echo "8")
readonly MAX_PARALLEL_JOBS

# Directory setup
GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
readonly GIT_ROOT_DIRECTORY
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SCRIPT_DIRECTORY

if [[ ! -f "$SCRIPT_DIRECTORY/check_changed.sh" ]]; then
  echo "Error: 'check_changed.sh' file not found in the current directory."
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/check_changed.sh"

# Get default branch name
get_default_branch() {
  git remote show "$(git remote)" | awk '/HEAD branch/ {print $NF}' | tr -d ' '
}

# Run shellcheck using either local installation or Docker
run_shellcheck() {
  local files=$1
  if command -v shellcheck; then
    # shellcheck disable=SC2086
    echo $files | xargs -n 1 -P "${MAX_PARALLEL_JOBS}" shellcheck -x
  else
    echo "Local shellcheck not found, using Docker..."
    docker pull "$DOCKER_IMAGE"
    # shellcheck disable=SC2086
    echo $files | xargs -n 1 -P "${MAX_PARALLEL_JOBS}" docker run --rm -w /mnt/ \
      -v "${GIT_ROOT_DIRECTORY}:/mnt/:ro" \
      "$DOCKER_IMAGE" shellcheck -x
  fi
}

# Get list of shell script files to check
get_shell_script_files() {
  local exclude_pattern
  #  exclude_pattern=$(printf " -type d -name '%s' -prune -o" "${EXCLUDED_DIRS[@]}")
  for dir in "${EXCLUDED_DIRS[@]}"; do
    exclude_pattern+=" -type d -name $dir -prune -o"
  done

  # shellcheck disable=SC2086
  find . $exclude_pattern \
    -type f -print0 |
    xargs -0 file |
    grep --line-buffered 'shell script\|\/usr\/bin\/env bash script\|zsh script' |
    cut -d ':' -f 1
}

# Process changed files
process_changed_files() {
  local files=$1
  local default_branch=$2
  local changed_files=""

  for file in $files; do
    if changed "$file" "$default_branch"; then
      changed_files="$changed_files $file"
    fi
  done
  echo "$changed_files"
}

# Main function
main() {
  local files=$*

  (cd "${GIT_ROOT_DIRECTORY}" || {
    echo "Error: Could not change to git root directory"
    exit 1
  })

  if [ -z "$files" ]; then
    echo "No files to check."
    return 0
  fi

  if [ "$CHECK_CHANGED" = "false" ]; then
    run_shellcheck "$files"
  else
    local default_branch
    default_branch=$(get_default_branch)
    local changed_files
    changed_files=$(process_changed_files "$files" "$default_branch")

    if [ -n "$changed_files" ]; then
      run_shellcheck "$changed_files"
    fi
  fi
}

# Script entry point
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  SHELL_SCRIPT_FILES=$(get_shell_script_files)
  main "$SHELL_SCRIPT_FILES"
fi
