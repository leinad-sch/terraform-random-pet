#!/bin/bash

if [[ -z $CI ]]; then
  CI=false
fi

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2 >/dev/null >&1 && pwd)"

check_installed() {
  if command -v "$1" 2 >/dev/null >&1; then
    return 0
  else
    return 1
  fi
}

os_detect() {
  case "$(uname)" in
  Linux*) echo "Linux" ;;
  Darwin*) echo "MacOS" ;;
  CYGWIN* | MINGW*) echo "Windows" ;;
  *) echo "Unknown" ;;
  esac
}

setup_macos_brew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

setup_macos_peru() {
  if ! brew install peru; then
    echo "Error: Failed to install 'peru' using Homebrew."
    exit 1
  fi
}

setup_macos() {
  check_installed "brew" || setup_macos_brew
  #  check_installed "peru" || setup_macos_peru
  check_installed "node" || (
    echo "please install node and extend this script"
    exit 1
  )
}

setup_other() {
  echo "I hope you know what you are doing."
  check_installed "node" || (
    echo "please install node and extend this script"
    exit 1
  )
  check_installed "peru" || (
    echo "please install peru and extend this script"
    exit 1
  )
}

setup_git_hooks() {
  if [[ "$CI" != "true" ]] && [[ -d "${SCRIPT_DIRECTORY}/.git-hooks/" ]]; then
    cp "${SCRIPT_DIRECTORY}/.git-hooks/"* "${SCRIPT_DIRECTORY}/.git/hooks/"
  fi
}

main() {
  OS_TYPE="$(os_detect)"
  case $OS_TYPE in
  MacOS)
    setup_macos
    ;;
  *)
    setup_other
    ;;
  esac

  setup_git_hooks
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  main
  echo "ok"
fi
