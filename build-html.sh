#!/usr/bin/env bash
# Build a self-contained HTML version of the resume.
#
# Usage: build-html.sh [output.html] [source.tex]
#
# The output embeds its stylesheet, so the resulting file has no external
# dependencies (apart from the links in the document itself).

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${2:-$ROOT/resume.tex}"
GIT_HASH="${GIT_HASH:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}"
OUT="${1:-$ROOT/dist/anas-resume-$GIT_HASH.html}"
THEME="${THEME:-modern}"

if ! command -v pandoc >/dev/null 2>&1; then
    echo "Error: pandoc is required to build the HTML version." >&2
    echo "Run this from 'nix develop', or install pandoc." >&2
    exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/resume-html.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

cp "$SRC" "$build_dir/resume.tex"
cp "$ROOT/pre-build.sh" "$build_dir/pre-build.sh"

# The PDF footer carries the build metadata; HTML does not render that footer,
# but pre-build.sh still needs a value.
GIT_HASH="$GIT_HASH" \
    PDFLATEX_VERSION="${PDFLATEX_VERSION:-HTML build}" \
    bash "$build_dir/pre-build.sh" "$build_dir/resume.tex"

# Pandoc does not evaluate TeX conditionals and cannot use textpos/qrcode.
# Keep the chosen header style and drop the PDF-only extras.
awk -v header_style="${HEADER_STYLE:-centric}" '
/^[[:space:]]*\\begin\{textblock\*\}/ { in_textblock=1; next }
in_textblock && /^[[:space:]]*\\end\{textblock\*\}/ { in_textblock=0; next }
in_textblock { next }

/^[[:space:]]*\\input\{glyphtounicode\}/ { next }

/^[[:space:]]*\\ifx\\headerStyle\\headerStyleCentric/ {
    if (header_style == "aligned") {
        skip_centric=1
    } else {
        keep_centric=1
    }
    next
}
skip_centric && /^[[:space:]]*\\else/ { skip_centric=0; keep_aligned=1; next }
keep_aligned && /^[[:space:]]*\\fi[[:space:]]*$/ { keep_aligned=0; next }
skip_centric { next }
keep_centric && /^[[:space:]]*\\else/ { keep_centric=0; skip_aligned=1; next }
skip_aligned && /^[[:space:]]*\\fi[[:space:]]*$/ { skip_aligned=0; next }
skip_aligned { next }

{ print }
' "$build_dir/resume.tex" > "$build_dir/resume.html.tex"

case "$THEME" in
    terminal)
        text='#222222'; accent='#008F11'; link='#008F11'
        ;;
    lightErth)
        text='#252F1E'; accent='#5F865F'; link='#B3854D'
        ;;
    lightErthAlt)
        text='#252F1E'; accent='#5F865F'; link='#B36B42'
        ;;
    everforest)
        text='#5C6A72'; accent='#35A77C'; link='#3A94C5'
        ;;
    everforestAlt)
        text='#5C6A72'; accent='#93B259'; link='#35A77C'
        ;;
    *)
        text='#000000'; accent='#191970'; link='#191970'
        ;;
esac

{
    cat "$ROOT/resume.css"
    printf '\n:root { --text: %s; --accent: %s; --link: %s; --rule: %s; }\n' \
        "$text" "$accent" "$link" "$accent"
} > "$build_dir/resume.css"

pandoc "$build_dir/resume.html.tex" \
    --from latex \
    --to html5 \
    --standalone \
    --embed-resources \
    --css "$build_dir/resume.css" \
    --metadata pagetitle='Anas Elgarhy - Resume' \
    --metadata lang=en \
    --output "$build_dir/resume.html"

mkdir -p "$(dirname -- "$OUT")"
cp -f "$build_dir/resume.html" "$OUT"
printf '%s\n' "$OUT"
