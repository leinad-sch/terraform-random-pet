#!/bin/bash

# Constants
MAX_PARALLEL_JOBS=$(nproc 2>/dev/null || echo "8")
readonly MAX_PARALLEL_JOBS
readonly DEFAULT_CHECKOV_VERSION="3.2.340"

GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
readonly GIT_ROOT_DIRECTORY
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SCRIPT_DIRECTORY

if [[ ! -f "$SCRIPT_DIRECTORY/utils.sh" ]]; then
  echo "Error: 'utils.sh' file not found in the current directory."
  exit 1
fi
# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/utils.sh"

if [[ ! -f "$GIT_ROOT_DIRECTORY/versions.sh" ]]; then
  echo "Warning: 'versions.sh' file not found in the current directory."
else
  # shellcheck source=/dev/null
  source "$GIT_ROOT_DIRECTORY/versions.sh"
fi

if [[ -z $CHECKOV_VERSION ]]; then
  CHECKOV_VERSION="$DEFAULT_CHECKOV_VERSION"
fi
readonly CHECKOV_VERSION

DOCKER_IMAGE="bridgecrew/checkov:${CHECKOV_VERSION}"
readonly DOCKER_IMAGE

run_checkov_local() {
  local directory="$1"
  checkov --version
  checkov -d "$directory"
}

run_checkov_docker() {
  local directory="$1"
  local quiet_flag="${2:-}"
  docker run --rm \
    -v "${GIT_ROOT_DIRECTORY}:/tf" \
    -w /tf \
    "${DOCKER_IMAGE}" \
    ${quiet_flag:+--quiet} -d "$directory"
}

process_single_directory() {
  local directory="$1"
  if command -v checkov &>/dev/null; then
    run_checkov_local "$directory"
  else
    run_checkov_docker "$directory"
  fi
}

process_multiple_directories() {
  local terraform_dirs
  terraform_dirs="$("$SCRIPT_DIRECTORY/list_terraform_directories.sh" 2>/dev/null)"
  local replsize
  replsize=$(get_xargs_replsize)

  if command -v checkov &>/dev/null; then
    checkov --version
    # shellcheck disable=SC2086 # intentional word splitting
    printf '%s\n' $terraform_dirs | xargs $replsize -n 1 -P "$MAX_PARALLEL_JOBS" -I '{}' \
      bash -c "$(declare -f process_single_directory); $(declare -f run_checkov_local); \
      process_single_directory '{}' || exit 255"
  else
    # shellcheck disable=SC2086 # intentional word splitting
    printf '%s\n' $terraform_dirs | xargs $replsize -n 1 -P "$MAX_PARALLEL_JOBS" -I '{}' \
      bash -c "$(declare -f process_single_directory); $(declare -f run_checkov_docker);\
      process_single_directory '{}' || exit 255"
  fi
}

main() {
  if [ "$CI" == "true" ] || [[ $# == 1 ]]; then
    process_single_directory "$1"
  else
    process_multiple_directories
  fi
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  main "$@"
fi
