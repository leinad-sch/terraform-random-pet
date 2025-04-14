#!/bin/bash

# Determine xargs replacement size parameter
get_xargs_replsize() {
  if xargs --help &>/dev/null; then
    echo ""
  else
    echo "-S 100000"
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

get_architecture() {
  local architecture
  architecture="$(uname -m)"

  if [[ "${architecture}" == "x86_64" ]]; then
    echo "amd64"
  else
    echo "${architecture}"
  fi
}
