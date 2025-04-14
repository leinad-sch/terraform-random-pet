#!/bin/bash
# Configuration constants
readonly DEFAULT_TERRAFORM_DOCS_VERSION="0.19.0"
if [[ -z $PARALLEL_JOBS ]]; then
  readonly PARALLEL_JOBS=8
fi
if [[ -z $DOCKER_IMAGE ]]; then
  readonly DOCKER_IMAGE="quay.io/terraform-docs/terraform-docs"
fi
if [[ -z $OUTPUT_FILE ]]; then
  readonly OUTPUT_FILE="README.md"
  export OUTPUT_FILE
fi

# shellcheck source=/dev/null
if [[ ! -f "$SCRIPT_DIRECTORY/utils.sh" ]]; then
  echo "Error: 'utils.sh' file not found in the current directory."
  exit 1
fi

if [[ ! -f "$GIT_ROOT_DIRECTORY/versions.sh" ]]; then
  echo "Warning: 'versions.sh' file not found in the current directory."
else
  # shellcheck source=/dev/null
  source "$GIT_ROOT_DIRECTORY/versions.sh"
fi

if [[ -z $TERRAFORM_DOCS_VERSION ]]; then
  readonly TERRAFORM_DOCS_VERSION="$DEFAULT_TERRAFORM_DOCS_VERSION"
fi

# Directory setup
GIT_ROOT_DIR="$(git rev-parse --show-toplevel)"
readonly GIT_ROOT_DIR
export GIT_ROOT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SCRIPT_DIR

# Generate documentation for a single directory
generate_docs_for_directory() {
  echo "Generating documentation for directory: $1"
  local target_dir="$1"

  if command -v terraform-docs &>/dev/null; then
    terraform-docs markdown table \
      --output-file "${OUTPUT_FILE}" \
      --output-mode inject \
      "${target_dir}"
  else
    docker run --rm \
      -v "${GIT_ROOT_DIR}:/terraform-docs" \
      -w /terraform-docs \
      "${DOCKER_IMAGE}:${TERRAFORM_DOCS_VERSION}" \
      markdown table \
      --output-file "${OUTPUT_FILE}" \
      --output-mode inject \
      "${target_dir}"
  fi
}

# Process multiple directories in parallel
process_directories() {
  echo "Processing directories in parallel..."
  local terraform_dirs
  terraform_dirs="$("$SCRIPT_DIR/list_terraform_directories.sh" 2>/dev/null)"

  # Determine xargs replacement size parameter
  local xargs_opts
  if xargs --help &>/dev/null; then
    xargs_opts=""
  else
    xargs_opts="-S 100000"
  fi

  # Process directories in parallel
  # shellcheck disable=SC2086 # intentional word splitting
  printf '%s\n' $terraform_dirs |
    xargs $xargs_opts -n 1 -P "${PARALLEL_JOBS}" -I '{}' \
      bash -c "$(declare -f generate_docs_for_directory); \
                 generate_docs_for_directory '{}' || exit 255"
}

main() {
  # Single directory mode
  if [ "$CI" == "true" ] || [[ $# == 1 ]]; then
    generate_docs_for_directory "$1"
  else
    process_directories
  fi
}

# Execute main only if script is run directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  main "$@"
fi
