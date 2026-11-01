{
  description = "Reproducible build of Anas Elgarhy's resume with pdflatex + latexmk";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # `eachDefaultSystem` also includes x86_64-darwin, which current nixpkgs no
  # longer supports, so the systems we care about are listed explicitly.
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        # These mirror the variables at the top of ./build.sh, which is what
        # ./x runs inside Docker.
        theme = "modern";
        headerStyle = "centric";
        # ./build.sh defines this as 'github\.com\/0x61nas' only so that it
        # survives sed; the text written to resume.tex is this plain value.
        gitHost = "github.com/0x61nas";
        gpgFingerprint = "EF4B4CB5DFB8822216A473B1597AB12E66262898";

        # Equivalent of `git rev-parse HEAD` in ./build.sh, taken from the
        # flake itself so the result is reproducible. Dirty trees get the same
        # clean hash as build.sh would produce.
        rev = self.rev or (lib.removeSuffix "-dirty" (self.dirtyRev or "dirty"));
        shortRev = lib.removeSuffix "-dirty" (self.shortRev or (lib.substring 0 7 rev));

        # build.sh used the host's /etc/os-release PRETTY_NAME here. Keep it to
        # plain text: characters like "_" are math-only in LaTeX.
        buildingPlatform = "NixOS ${lib.versions.majorMinor lib.version}";

        tex = pkgs.texliveSmall.withPackages (
          ps: with ps; [
            latexmk
            titlesec
            enumitem
            fancyhdr
            hyperref
            xcolor
            babel
            babel-english
            textpos
            qrcode
            marvosym
            preprint # fullpage
            charter
            cormorantgaramond
            xkeyval
            fontaxes
            iftex
          ]
        );

        resume = pkgs.stdenvNoCC.mkDerivation {
          pname = "anas-resume";
          version = shortRev;

          # For git checkouts this is the tracked tree, i.e. what build.sh
          # copies into build/.
          src = self;

          nativeBuildInputs = [ tex ];

          # Consumed by ./pre-build.sh, which fills in the @{...} placeholders
          # exactly the way build.sh does.
          GIT_HASH = rev;
          GPG_FINGREPRINT = gpgFingerprint;
          GIT_HOST = gitHost;
          THEME = theme;
          HEADER_STYLE = headerStyle;
          BUILDING_PLATFORM = buildingPlatform;

          # Keep TeX from trying to write caches into $HOME.
          TEXMFHOME = "./texmf-home";
          TEXMFVAR = "./texmf-var";

          # Don't leak the build time into the PDF (\today and the metadata).
          SOURCE_DATE_EPOCH = toString self.lastModified;
          FORCE_SOURCE_DATE = "1";

          # The substitution logic lives in ./pre-build.sh so that nix builds
          # and build.sh stay in sync.
          buildPhase = ''
            runHook preBuild

            bash ./pre-build.sh ./resume.tex
            latexmk -pdf resume.tex

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm644 resume.pdf "$out/anas-resume-${rev}.pdf"
            runHook postInstall
          '';

          meta = {
            description = "Anas Elgarhy's resume";
            homepage = "https://thatsillyman.win";
          };
        };

        html = pkgs.stdenvNoCC.mkDerivation {
          pname = "anas-resume-html";
          version = shortRev;

          src = self;

          nativeBuildInputs = [ pkgs.pandoc ];

          GIT_HASH = rev;
          THEME = theme;
          HEADER_STYLE = headerStyle;
          BUILDING_PLATFORM = buildingPlatform;
          PDFLATEX_VERSION = "HTML build";

          buildPhase = ''
            runHook preBuild

            bash ./build-html.sh "$TMPDIR/anas-resume-${rev}.html"

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm644 "$TMPDIR/anas-resume-${rev}.html" "$out/anas-resume-${rev}.html"
            runHook postInstall
          '';

          meta = {
            description = "Anas Elgarhy's resume as a self-contained HTML file";
            homepage = "https://thatsillyman.win";
          };
        };
      in
      {
        packages = {
          default = resume;
          inherit html;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            tex
            pkgs.git
            pkgs.texlab
            pkgs.zathura
            pkgs.wmctrl
            pkgs.pandoc
          ];
        };

        formatter = pkgs.nixfmt;
      }
    );
}
