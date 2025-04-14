#!/bin/bash
GIT_ROOT_DIRECTORY="$(git rev-parse --show-toplevel)"
readonly GIT_ROOT_DIRECTORY
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SCRIPT_DIRECTORY

MAX_PARALLEL_JOBS=$(nproc 2>/dev/null || echo "8")
readonly MAX_PARALLEL_JOBS

readonly DEFAULT_TERRAFORM_VERSION="1.9.5"
readonly CACHE_DIR="/tmp/bin/"

if [[ ! -f "$GIT_ROOT_DIRECTORY/versions.sh" ]]; then
  echo "Warning: 'versions.sh' file not found in the current directory."
else
  # shellcheck source=/dev/null
  source "$GIT_ROOT_DIRECTORY/versions.sh"
fi

if [[ -z $TERRAFORM_VERSION ]]; then
  TERRAFORM_VERSION="$DEFAULT_TERRAFORM_VERSION"
fi

if [[ ! -f "$SCRIPT_DIRECTORY/utils.sh" ]]; then
  echo "Error: 'utils.sh' file not found in the current directory."
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIRECTORY/utils.sh"

setup_terraform() {
  (
    mkdir -p "${CACHE_DIR}"
    cd "$CACHE_DIR" || exit

    local architecture
    architecture=$(get_architecture)

    curl "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_${architecture}.zip" -O
    unzip "terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_${architecture}.zip"
    rm "terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_${architecture}.zip"
  )
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  if [[ "$CI" == "true" ]] || [[ $# == 1 ]]; then
    if [[ "$CI" == "true" ]]; then
      if [[ ! -f "${CACHE_DIR}/terraform" ]]; then
        echo "Installing Terraform to ${CACHE_DIR}"
        setup_terraform
        echo "Using $("${CACHE_DIR}/terraform" -v | head -n1)..."
      else
        echo "Using cached $("${CACHE_DIR}/terraform" -v | head -n1) from ${CACHE_DIR}..."
      fi

      cd "$1" && "${CACHE_DIR}/terraform" fmt -check -recursive -diff
    else
      echo "Using $(terraform -v | head -n1)"
      echo "$1"
      (cd "$1" && terraform fmt -check -recursive -diff -write=true -list=true)
    fi
  else
    echo "Using $(terraform -v | head -n1)"
    TERRAFORM_DIRECTORIES="$("$SCRIPT_DIRECTORY/list_terraform_directories.sh" 2>/dev/null)"

    xargs --help &>/dev/null && replsize="" || replsize="-S 100000"

    # shellcheck disable=SC2086 # intentional word splitting
    printf '%s\n' $TERRAFORM_DIRECTORIES | xargs $replsize -n 1 -P "${MAX_PARALLEL_JOBS}" -I '{}' \
      bash -c "cd ${GIT_ROOT_DIRECTORY}/{} && terraform fmt -check -recursive -diff -write=false -list=true || exit 255"
    CHECK_EXIT_CODE=$?
    if [[ "$LAST_EXIT_CODE" == "1" ]]; then
      # shellcheck disable=SC2086 # intentional word splitting
      printf '%s\n' $TERRAFORM_DIRECTORIES | xargs $replsize -n 1 -P "${MAX_PARALLEL_JOBS}" -I '{}' \
        bash -c "cd ${GIT_ROOT_DIRECTORY}/{} && terraform fmt -recursive -write=true || exit 255"
      FIX_EXIT_CODE=$?
    fi
    if [[ -n "$FIX_EXIT_CODE" ]]; then
      if [[ "$FIX_EXIT_CODE" == "0" ]]; then
        exit "$CHECK_EXIT_CODE"
      else
        exit "$FIX_EXIT_CODE"
      fi
    else
      exit "$CHECK_EXIT_CODE"
    fi
  fi
fi
