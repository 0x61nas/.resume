#!/usr/bin/env bash

set -euo pipefail

GPG_KEY='EF4B4CB5DFB8822216A473B1597AB12E66262898'
WEBSITE_DIR="$HOME/code/website"
ARCHIVE_DIR="$WEBSITE_DIR/resume/archive"

declare -A GIT_REMOTES=(
    [origin]="git@github.com:0x61nas/.resume.git"
    [gitlab]="git@gitlab.com:anelgarhy/resume.git"
    [gitea]="git@gitea.com:0x61nas/resume.git"
    [codeberg]="ssh://git@codeberg.org/0x61nas/resume.git"
    [disroot]="ssh://git@git.disroot.org/anas/resume.git"
    [tangled]="git@tangled.org:anas.tngl.sh/resume"
    [codefloe]="ssh://git@codefloe.com/anas/resume.git"
)

ok()   { echo -e "DONE: $1"; }
fail() { echo -e "FAIL: $1"; }
info() { echo -e "INFO: $1"; }
warn() { echo -e "WARN: $1"; }

usage() {
    cat <<EOF
Usage: x <command> [args]

Commands:
  compile, c, build      Build and publish the resume (nix on NixOS, Docker otherwise)
  compile-docker, cd     Build and publish the resume with the Docker flow
  publish <pdf>          Sign a built PDF and copy it into the website repo
  push, p [flags] [branch]
                         Push branch to all remotes (default: -u aurora)
  push-tags, pt [flags] [branch]
                         Push branch and tags to all remotes
  clean                  Remove build artefacts
  setup-remotes, sr      Register all git remotes
  print-remotes, pr      Display configured git remotes
  help, h                Show this help message
EOF
    exit 0
}

error() {
    local arg="${1-}"
    echo -e "Error: unknown command '${arg}'" >&2
    echo "Run 'x help' for usage" >&2
    exit 1
}

echo_nd_run() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    "$@"
}

compile() {
    if [[ -e /etc/NIXOS ]]; then
        info 'Building the resume with nix...'
        echo_nd_run nix build --print-build-logs

        mkdir -p dist
        local output_file
        output_file="dist/$(basename "$(readlink -f result)"/*.pdf)"
        echo_nd_run cp -f result/*.pdf "$output_file"

        publish "$output_file"
    else
        compile-docker
    fi
}

compile-docker() {
    info 'Building the resume with Docker...'
    echo_nd_run docker run -it --network=host -w '/work' -v "$(pwd):/work" latex-docker:latest bash -c "git config --global safe.directory '*' && ./build.sh"

    local output_file
    output_file="dist/$(cat build/output_path)"
    echo_nd_run doas chown anas:anas "$output_file"
    echo_nd_run doas chmod 644 "$output_file"

    publish "$output_file"
}

publish() {
    local pdf="${1:?usage: x publish <pdf>}"
    local pdf_name="${pdf##*/}"

    info "Publishing $pdf..."
    echo_nd_run chmod 644 "$pdf"
    echo_nd_run gpg --local-user "$GPG_KEY" --detach-sign --armor "$pdf"
    echo_nd_run cp "$pdf" "$ARCHIVE_DIR/"
    echo_nd_run cp "$pdf.asc" "$ARCHIVE_DIR/"
    echo_nd_run ln -srfv "$ARCHIVE_DIR/$pdf_name" "$WEBSITE_DIR/static/docs/anas-resume.pdf"
    echo_nd_run ln -srfv "$ARCHIVE_DIR/$pdf_name.asc" "$WEBSITE_DIR/static/docs/anas-resume.pdf.asc"
    echo_nd_run ln -srfv "$ARCHIVE_DIR/$pdf_name" "$WEBSITE_DIR/resume/anas-resume.pdf"
    echo_nd_run ln -srfv "$ARCHIVE_DIR/$pdf_name.asc" "$WEBSITE_DIR/resume/anas-resume.pdf.asc"
    ok 'published'
}

print-remotes() {
    for remote in "${!GIT_REMOTES[@]}"; do
        echo "  $remote -> ${GIT_REMOTES[$remote]}"
    done
}

setup-remotes() {
    for remote in "${!GIT_REMOTES[@]}"; do
        if git remote add "$remote" "${GIT_REMOTES[$remote]}" 2>/dev/null; then
            ok "added remote $remote"
        else
            warn "remote $remote already exists"
        fi
    done
}

push() {
    local flags=()
    local branch="aurora"

    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            flags+=("$arg")
        else
            branch="$arg"
        fi
    done

    [[ ${#flags[@]} -eq 0 ]] && flags=("-u")

    local flag_str="${flags[*]}"
    echo -e "Pushing to all remotes"
    echo -e "  Branch: $branch  Flags: ${flag_str:-(none)}"
    echo

    local ok=true
    for remote in "${!GIT_REMOTES[@]}"; do
        info "pushing to $remote..."
        if git push "${flags[@]}" "$remote" "$branch"; then
            ok "pushed to $remote"
        else
            fail "failed to push to $remote"
            ok=false
        fi
    done
    echo
    if $ok; then
        ok "all pushes succeeded"
    else
        fail "some pushes failed"
        return 1
    fi
}

push-tags() {
    push "$@"
    echo
    echo -e "Pushing tags to all remotes"
    echo
    local ok=true
    for remote in "${!GIT_REMOTES[@]}"; do
        info "pushing tags to $remote..."
        if git push --tags "$remote"; then
            ok "tags pushed to $remote"
        else
            fail "failed to push tags to $remote"
            ok=false
        fi
    done
    echo
    if $ok; then
        ok "all tag pushes succeeded"
    else
        fail "some tag pushes failed"
        return 1
    fi
}

clean() {
    echo -e "Cleaning untracked files"
    echo_nd_run git clean -ffdx
    ok "clean complete"
}

arg="${1-}"
[[ -z "$arg" ]] && usage
shift

case $arg in
    help|h|--help|-h) usage ;;
    compile|c|build|b) compile ;;
    compile-docker|cd) compile-docker ;;
    publish|pub) publish "$@" ;;
    print-remotes|pr) print-remotes ;;
    setup-remotes|sr) setup-remotes ;;
    push|p) push "$@" ;;
    push-tags|pusht|pt) push-tags "$@" ;;
    clean) clean ;;
    *) error "$arg" ;;
esac
