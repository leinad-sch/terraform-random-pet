#!/bin/bash
# Configuration constants
readonly DEFAULT_TFLINT_BUNDLE_VERSION="v0.56.0"
readonly DEFAULT_LOG_LEVEL="error"
readonly DOCKER_IMAGE="ghcr.io/terraform-linters/tflint"
export DOCKER_IMAGE
readonly DOCKER_WORKDIR="/data"
export DOCKER_WORKDIR
MAX_PARALLEL_JOBS=$(nproc 2>/dev/null || echo "8")
readonly MAX_PARALLEL_JOBS

# Directory paths
GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
readonly GIT_ROOT_DIRECTORY
export GIT_ROOT_DIRECTORY
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

if [[ -z $TFLINT_BUNDLE_VERSION ]]; then
  export TFLINT_BUNDLE_VERSION="$DEFAULT_TFLINT_BUNDLE_VERSION"
fi

get_log_level() {
  if [[ "$DEBUG" == true ]]; then
    echo "trace"
  else
    echo "$DEFAULT_LOG_LEVEL"
  fi
}

run_tflint_local() {
  local target_dir="$1"
  local log_level="$2"

  TFLINT_LOG="$log_level" tflint --chdir "${target_dir}"
}

run_tflint_docker() {
  local target_dir="$1"
  local log_level="$2"

  docker run --rm \
    -e "TFLINT_LOG=$log_level" \
    -v "${GIT_ROOT_DIRECTORY}:/data" \
    -w "$DOCKER_WORKDIR" \
    "${DOCKER_IMAGE}:${TFLINT_BUNDLE_VERSION}" \
    --chdir "${target_dir}"
}

run_parallel_tflint() {
  local log_level="$1"
  local terraform_dirs
  if [[ -z $2 ]]; then
    terraform_dirs="$("$SCRIPT_DIRECTORY/list_terraform_directories.sh" 2>/dev/null)"
  else
    terraform_dirs="$2"
  fi

  local replsize
  replsize=$(get_xargs_replsize)

  if command -v tflint &>/dev/null; then
    # shellcheck disable=SC2086 # intentional word splitting
    printf '%s\n' $terraform_dirs | xargs $replsize -n 1 -P "$MAX_PARALLEL_JOBS" -I '{}' \
      bash -c "$(declare -f run_tflint_local); \
      run_tflint_local '{}' '$log_level' || exit 255"
  else
    # shellcheck disable=SC2086 # intentional word splitting
    printf '%s\n' $terraform_dirs | xargs $replsize -n 1 -P "$MAX_PARALLEL_JOBS" -I '{}' \
      bash -c "$(declare -f run_tflint_docker); run_tflint_docker '{}' '$log_level' || exit 255"
  fi
}

main() {
  local log_level
  log_level=$(get_log_level)

  if [ "$CI" == "true" ] || [[ $# == 1 ]]; then
    run_parallel_tflint "$log_level" "$1"
  else
    run_parallel_tflint "$log_level"
  fi
}

# Execute main only if script is run directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  main "$@"
fi
