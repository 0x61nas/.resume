#!/usr/bin/env bash
# Fill in the @{...} placeholders in the resume source.
#
# This is the single place that knows how the build metadata (git hash, theme,
# platform, pdfTeX version, ...) ends up in resume.tex. It is called by
# build.sh (Docker/local builds) and by flake.nix (nix build), so both produce
# the same document.
#
# Every value can be overridden from the environment; the defaults below match
# the constants that used to live in build.sh.
#
# Usage: pre-build.sh <resume.tex>

set -euo pipefail

DOC="${1:?usage: $0 <resume.tex>}"

: "${GIT_HASH:=$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
: "${GPG_FINGREPRINT:=EF4B4CB5DFB8822216A473B1597AB12E66262898}"
: "${GIT_HOST:=github.com/0x61nas}"
: "${THEME:=modern}"
: "${HEADER_STYLE:=centric}"
: "${PDFLATEX_VERSION:=$(pdflatex -version | sed -n '1p')}"

if [[ -z "${BUILDING_PLATFORM:-}" ]]; then
    if [[ -r /etc/os-release ]]; then
        BUILDING_PLATFORM=$(set +u; . /etc/os-release; printf '%s' "${PRETTY_NAME:-Unknown}")
    else
        BUILDING_PLATFORM="Unknown"
    fi
fi

fail() {
    echo "Error: " "$@" >/dev/stderr
    exit 1
}

replace() {
    local placeholder=$1 value=$2

    sed -i "s/$placeholder/$value/g" "$DOC" | fail "Failed to process the `$placeholder` pre-processor"
}

replace '@{GIT_HASH}' "$GIT_HASH"
replace '@{GPG_FINGREPRINT}' "$GPG_FINGREPRINT"
replace '@{GIT_HOST}' "$GIT_HOST"
replace '@{THEME}' "$THEME"
replace '@{HEADER_STYLE}' "$HEADER_STYLE"
replace '@{BUILDING_PLATFORM}' "$BUILDING_PLATFORM"
replace '@{PDFLATEX_VERSION}' "$PDFLATEX_VERSION"
