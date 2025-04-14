#!/bin/bash
#GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
#SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Constants
readonly DOCKER_YAMLLINT_IMAGE="cytopia/yamllint:1.26"
readonly EXCLUDED_DIRS=(
  '.git'
  '.terragrunt-cache'
  '.terraform'
  'node_modules'
  '.peru'
  '.peru-deps'
)
readonly YAML_EXTENSIONS=('*.yaml' '*.yml')

# Initialize global variables
GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEFAULT_BRANCH="$(git remote show "$(git remote)" | grep 'HEAD branch' | cut -d ':' -f 2- | tr -d ' ')"

if [[ ! -f "$SCRIPT_DIRECTORY/check_changed.sh" ]]; then
  echo "Error: 'check_changed.sh' file not found in the current directory."
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/check_changed.sh"

if [[ ! -f "$SCRIPT_DIRECTORY/utils.sh" ]]; then
  echo "Error: 'utils.sh' file not found in the current directory."
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/utils.sh"

run_local_yamllint() {
  local file="$1"
  yamllint "$file" || exit 255
}

run_docker_yamllint() {
  local file="$1"
  docker run --rm \
    -v "${GIT_ROOT_DIRECTORY}:/workdir:ro" \
    -w /workdir \
    "${DOCKER_YAMLLINT_IMAGE}" \
    "$file" || exit 255
}

check_yamllint() {
  local -a files=("$@")
  local replsize
  replsize=$(get_xargs_replsize)

  # Use nproc if available for optimal parallel processing
  PARALLEL_JOBS=$(nproc 2>/dev/null || echo "8")

  if command -v yamllint; then
    # shellcheck disable=SC2068
    # shellcheck disable=SC2086
    printf '%s\n' ${files[@]} | xargs $replsize -L 1 -n 1 -P "$PARALLEL_JOBS" -I '{}' bash -c "$(declare -f run_local_yamllint); \
      run_local_yamllint '{}' || exit 255"
  else
    # shellcheck disable=SC2068
    # shellcheck disable=SC2086
    printf '%s\n' ${files[@]} | xargs $replsize -L 1 -n 1 -P "$PARALLEL_JOBS" -I '{}' bash -c "$(declare -f run_docker_yamllint); \
      run_docker_yamllint '{}' || exit 255"
  fi
}

get_changed_files() {
  local -a files=("$@")
  local changed_files=()

  for file in "${files[@]}"; do
    if changed "$file" "${DEFAULT_BRANCH}" >/dev/null; then
      changed_files+=("$file")
    fi
  done
  echo "${changed_files[@]}"
}

main() {
  local -a files=("$@")

  (
    cd "${GIT_ROOT_DIRECTORY}" || exit 1

    if [ ${#files[@]} -eq 0 ]; then
      echo "No files to check."
      return
    fi

    if [ "$CHECK_CHANGED_FILES" == "false" ]; then
      check_yamllint "${files[@]}"
    else
      local changed_files
      changed_files=()
      while IFS='' read -r line; do changed_files+=("$line"); done < <(get_changed_files "${files[@]}")

      if [ ${#changed_files[@]} -gt 0 ]; then
        check_yamllint "${changed_files[@]}"
      fi
    fi
  )
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  # Build find command for YAML files
  find_cmd="find . -type f "

  # Add exclusion patterns
  for dir in "${EXCLUDED_DIRS[@]}"; do
    find_cmd+=" -type d -name $dir -prune -o"
  done

  # Add YAML file patterns
  find_cmd+=" -type f ( -name ${YAML_EXTENSIONS[0]} -o -name ${YAML_EXTENSIONS[1]} ) -print"

  # Execute find command
  YAML_FILES=()
  # shellcheck disable=SC2086
  while IFS='' read -r line; do
    [[ -f "$line" ]] && YAML_FILES+=("$line")
  done < <(${find_cmd})

  if [[ ${#YAML_FILES[@]} -eq 0 ]]; then
    echo "Warning: No YAML files found" >&2
  fi

  main "${YAML_FILES[@]}"
fi
