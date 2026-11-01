# resume

> "LaTeX is the only programming language where a missing brace can cost you a job."

Anas's résumé, built reproducibly with Nix or Docker.

## Build

With `x`:

```sh
./x compile          # nix on NixOS, Docker everywhere else
./x compile-docker   # force the Docker flow
./x clean
```

Without `x`:

```sh
# On NixOS
nix build --print-build-logs
mkdir -p dist
cp -f result/*.pdf dist/

# With Docker
docker run -it --network=host -w /work -v "$(pwd):/work" \
  latex-docker:latest bash -c "git config --global safe.directory '*' && ./build.sh"
```

The Docker flow writes the PDF to `dist/` and its filename to `build/output_path`.
