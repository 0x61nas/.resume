#!/usr/bin/env just --justfile

OUTDIR := "."
_main := "resume.tex"
_pdf_prog := "zathura"
_compiler := "pdflatex"
_cflags := "-halt-on-error -output-directory=" + OUTDIR

# alias w := whatch
alias c := compile
alias p := push

# Build and publish the resume: nix on NixOS, Docker everywhere else.
compile:
    #!/usr/bin/env bash
    set -euxo pipefail
    if [[ -e /etc/NIXOS ]]; then
        nix build --print-build-logs
        mkdir -p dist
        _OUTPUT_FILE=dist/$(basename "$(readlink -f result)"/*.pdf)
        cp -f result/*.pdf "$_OUTPUT_FILE"
        just _publish "$_OUTPUT_FILE"
    else
        just compile-docker
    fi

# Build and publish the resume with the old Docker flow.
compile-docker:
    #!/usr/bin/env bash
    set -euxo pipefail
    docker run -it --network=host -w '/work' -v "$(pwd):/work" latex-docker:latest bash -c "git config --global safe.directory '*' && ./build.sh"
    _OUTPUT_FILE=dist/$(cat build/output_path)
    doas chown anas:anas "$_OUTPUT_FILE"
    doas chmod 644 "$_OUTPUT_FILE"
    just _publish "$_OUTPUT_FILE"

# Sign a built PDF and copy it into the website repo (used by the recipes above).
_publish _pdf:
    #!/usr/bin/env bash
    set -euxo pipefail
    _OUTPUT_FILE={{quote(_pdf)}}
    _OUTPUT_FILE_NAME=${_OUTPUT_FILE##*/}
    chmod 644 "$_OUTPUT_FILE"
    gpg --local-user EF4B4CB5DFB8822216A473B1597AB12E66262898 --detach-sign --armor "$_OUTPUT_FILE"
    cp "$_OUTPUT_FILE" ~/code/website/resume/archive/
    cp "$_OUTPUT_FILE.asc" ~/code/website/resume/archive/
    ln -srfv "$HOME/code/website/resume/archive/$_OUTPUT_FILE_NAME" ~/code/website/static/docs/anas-resume.pdf
    ln -srfv "$HOME/code/website/resume/archive/$_OUTPUT_FILE_NAME.asc" ~/code/website/static/docs/anas-resume.pdf.asc
    ln -srfv "$HOME/code/website/resume/archive/$_OUTPUT_FILE_NAME" ~/code/website/resume/anas-resume.pdf
    ln -srfv "$HOME/code/website/resume/archive/$_OUTPUT_FILE_NAME.asc" ~/code/website/resume/anas-resume.pdf.asc

# compile compiler=_compiler cflags=_cflags main=_main:
# 	{{compiler}} {{cflags}} {{main}}
# 	# bibtex resume
# 	# {{compiler}} {{cflags}} {{main}}
# 	# {{compiler}} {{cflags}} {{main}}

# preview prog=_pdf_prog compiler=_compiler cflags=_cflags main=_main: (compile compiler cflags main)
# 	{{prog}} {{OUTDIR}}/resume.pdf
#
#
# whatch prog=_pdf_prog compiler=_compiler cflags=_cflags main=_main:
# 	just preview {{prog}} &
# 	echo "{{main}}" | entr just compile "{{compiler}}" "{{cflags}}" "{{main}}"

clean:
	rm -fr *.toc *.snm *.out *.nav *.blg *.log *.bbl *.aux resume.pdf build/

push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} origin {{BRANSH}} 
    git push {{FLAGS}} gitlab {{BRANSH}} 
    git push {{FLAGS}} gitea {{BRANSH}} 
    git push {{FLAGS}} codeberg {{BRANSH}} 
    git push {{FLAGS}} disroot {{BRANSH}} 
    git push {{FLAGS}} tangled {{BRANSH}} 
    git push {{FLAGS}} codefloe {{BRANSH}} 
