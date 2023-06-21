#!/bin/bash

set -e

die() { echo "$*" >&2; exit 1; }

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OS="$(echo $(uname -s) | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
# Normalize the architecture
if [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
fi

SANITIZER=""

# From https://stackoverflow.com/a/28466267
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts h-: OPT; do
  if [ "$OPT" = "-" ]; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    sanitizer ) needs_arg; SANITIZER="$OPTARG" ;;
    h | help ) echo "Usage: $0 [--sanitizer=address|memory]"; exit 0 ;;
    ??* ) die "Illegal option --$OPT" ;;
    ? ) exit 2 ;;
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

if [[ "$SANITIZER" == "" ]]; then
  die "No sanitizer specified"
fi

if [[ "$OS" != "linux" ]]; then
  die "Only linux is supported"
fi

if [[ "$ARCH" != "x86_64" ]]; then
  die "Only x86_64 is supported"
fi

GO_ARCH="amd64"
LINUX_ARCH="x86_64"
TARGET_TRIPLE="$LINUX_ARCH-linux-gnu"

echo "Build a native library for $SANITIZER on $OS/$ARCH"

CC="$BASE_DIR/third_party/llvm-build/Release+Asserts/bin/clang"
AR="$BASE_DIR/third_party/llvm-build/Release+Asserts/bin/llvm-ar"

CFLAGS="--target=$TARGET_TRIPLE -nostdinc -isysroot $BASE_DIR/build/linux/debian_bullseye_$GO_ARCH-sysroot \
  -isystem $BASE_DIR/third_party/llvm-build/Release+Asserts/lib/clang/17/include \
  -isystem $BASE_DIR/third_party/build/linux/debian_bullseye_$GO_ARCH-sysroot/usr/include  \
  -isystem $BASE_DIR/third_party/build/linux/debian_bullseye_$GO_ARCH-sysroot/usr/include/$LINUX_ARCH-linux-gnu"

# Additional flags for sanitizer
if [[ "$SANITIZER" == "asan" ]]; then
  CFLAGS="$CFLAGS -fsanitize=address"
elif [[ "$SANITIZER" == "msan" ]]; then
  CFLAGS="$CFLAGS -fsanitize=memory"
else
  die "Unknown sanitizer $SANITIZER"
fi

pushd native || die "Failed to cd"
rm -rf libfoo.a foo.o
"$CC" -c -fPIC -o foo.o foo.c "$CFLAGS"
"$AR" rcs libfoo.a foo.o
popd

echo "Build a Go library for $SANITIZER on $OS/$ARCH"
export CC="$CC"

export CGO_CFLAGS="$CFLAGS"
export CGO_LDFLAGS="-fuse-ld=lld --target=$TARGET_TRIPLE --sysroot $BASE_DIR/third_party/build/linux/debian_bullseye_$GO_ARCH-sysroot \
  -L $BASE_DIR/third_party/build/linux/debian_bullseye_$GO_ARCH-sysroot/usr/lib/$LINUX_ARCH-linux-gnu \
  -rdynamic \
  -L $BASE_DIR/native"

# Additional flags for sanitizer
if [[ "$SANITIZER" == "asan" ]]; then
  export CGO_CFLAGS="$CGO_CFLAGS -fsanitize=address -fsanitize=leak"
  export CGO_LDFLAGS="$CGO_LDFLAGS -fsanitize=address -fsanitize=leak \
  $BASE_DIR/third_party/llvm-build/Release+Asserts/lib/clang/17/lib/x86_64-unknown-linux-gnu/libclang_rt.asan_cxx.a"
elif [[ "$SANITIZER" == "msan" ]]; then
  export CGO_CPPFLAGS="$CGO_CPPFLAGS -fsanitize=memory"
  export CGO_LDFLAGS="$CGO_LDFLAGS -fsanitize=memory \
    $BASE_DIR/third_party/llvm-build/Release+Asserts/lib/clang/17/lib/x86_64-unknown-linux-gnu/libclang_rt.msan.a \
    $BASE_DIR/third_party/llvm-build/Release+Asserts/lib/clang/17/lib/x86_64-unknown-linux-gnu/libclang_rt.msan_cxx.a"
fi

if [[ "$SANITIZER" == "asan" ]]; then
  export ASAN_OPTIONS=detect_leaks=1
  export ASAN_SYMBOLIZER_PATH="$BASE_DIR/third_party/llvm-build/Release+Asserts/bin/llvm-symbolizer"
elif [[ "$SANITIZER" == "msan" ]]; then
  export MSAN_SYMBOLIZER_PATH="$BASE_DIR/third_party/llvm-build/Release+Asserts/bin/llvm-symbolizer"
fi

ARGS=""

if [[ "$SANITIZER" == "asan" ]]; then
  ARGS="$ARGS -tags asan"
elif [[ "$SANITIZER" == "msan" ]]; then
  ARGS="$ARGS -tags msan"
fi

export GODEBUG=cgocheck=2

go build -o main ${ARGS} github.com/bc-lee/test-golang-cgo-sanitizers

echo "Run the Go binary"
./main
