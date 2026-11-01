#!/usr/bin/env bash

set -euo pipefail

PROOT="$PWD"
GIT_HASH=$(git rev-parse HEAD)
BUILD_DIR="$PROOT/build"
DIST_DIR="$PROOT/dist"

fail() {
	echo "Error: " "$@" >/dev/stderr
	exit 1
}

log() {
	echo "$@" >/dev/stderr
}

if [[ -d "$BUILD_DIR" ]]; then
	log "Clean up the build dir..."
	rm -rf "$BUILD_DIR"/* || fail
else
	log "the build directory does not exsist!"
	log "creating a new build directory.."
	mkdir "$BUILD_DIR" || fail
fi

cp ./resume.tex ./latexmk ./pre-build.sh "$BUILD_DIR" || fail

cd "$BUILD_DIR" || fail

# Fill in the @{...} placeholders. The same script is used by flake.nix.
GIT_HASH="$GIT_HASH" bash ./pre-build.sh ./resume.tex || fail

latexmk -pdf resume.tex || fail

if [[ ! -d "$DIST_DIR" ]]; then
	mkdir -p "$DIST_DIR"
fi

cp resume.pdf "$DIST_DIR/anas-resume-$GIT_HASH.pdf"

echo "anas-resume-$GIT_HASH.pdf" >output_path
