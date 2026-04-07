#!/bin/bash

set -euf -o pipefail
shopt -s inherit_errexit

scriptDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

function echoError() {
  (echo >&2 "$1")
  return
}

function echoErrorInRed() {
  declare message
  message="$1"
  (echo >&2 "$(tput setaf 1)${message}$(tput sgr0)")
}


function compile() {
  curDir=$(pwd)
  cd "$scriptDir"  

  # Strip any file extension. Assume it is .cu
  file="$1"
  fileNoExtension="${file%.*}"

  echoErrorInRed "Compiling $file"
  # Use --expt-relaxed-constexpr for std::format inside kernel

  mkdir -p "bin"

  # Add  --resource-usage if you want details of register usage.
  nvcc \
    -ccbin /usr/local/gcc-13.3.0/bin/g++-13.2.0 \
    -std=c++20 \
    -lineinfo \
    -arch=sm_86 \
    --expt-relaxed-constexpr -lcurand \
    "$file" -o "bin/$fileNoExtension" 2>&1 | tee /tmp/ptxres

  grep -i "registers" -B2 /tmp/ptxres || true

  echoErrorInRed "Compiling Done"
  echoErrorInRed "--------------------------------------"
  cd "$curDir"
}

function execute() {
  file="$1"
  fileNoExtension="${file%.*}"
  shift

  echoErrorInRed "Executing now: $fileNoExtension"
  echoErrorInRed "--------------------------------------"
  LD_LIBRARY_PATH="/usr/local/gcc-13.3.0/lib64" "$scriptDir/bin/$fileNoExtension" "$@"
}

# Usage (regardless of working directory): 
# /path/to/script compile bf.cu
# /path/to/script bf.cu # Runs the previously compiled bf
# /path/to/script bf <vertices> <edges> <itersPerBatch> <blockSize> <blockCount> <algo=scattered|newBest_one|newBest_batch>
function main() {
  if [[ "$1" = "compile" ]]; then
    shift
    compile "$1"
  fi

  execute "$@"
}

main "$@"
