#!/bin/bash

set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$BASE_DIR"
third_party/tools/clang/scripts/update.py --output third_party/llvm-build/Release+Asserts

third_party/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
