local wing = require("wing")

-- Mojo is not in nixpkgs and is not open source: Modular publishes it as a conda package under
-- their own licence. The dev shell unpacks that package, so the versions below are a pin against
-- whatever conda.modular.com serves today. `mblack` is the formatter, a separate package that
-- `mojo format` expects to find inside the compiler's own bin directory.
wing.template("mojo", {
  description = "Mojo CLI app with .make.lua, flake.nix, tests, and release hooks",
  language = "mojo",
  framework = "cli",
  tags = { "builtin", "mojo", "cli" },
  environment = "The dev shell unpacks a pinned Mojo compiler and its formatter from Modular's " ..
                "conda channel; Mojo is published under the Modular Community License rather " ..
                "than an open one.",
  nix_packages = [[
            (
              let
                # The formatter mojo shells out to: pure Python, so it is the conda payload's
                # site-packages put behind a `python -m mblack` wrapper.
                mblack =
                  let
                    py = pkgs.python3.withPackages (ps: with ps; [
                      click mypy-extensions packaging pathspec platformdirs tomli
                    ]);
                  in
                  pkgs.stdenv.mkDerivation {
                    pname = "mblack";
                    version = "26.5.0";
                    src = pkgs.fetchurl {
                      url = "https://conda.modular.com/max/noarch/mblack-26.5.0-release.conda";
                      hash = "sha256-SRArVTZuq1awRiBTMwK4aTtPpKbFlys8yXiz87rYPr4=";
                    };
                    nativeBuildInputs = [ pkgs.unzip pkgs.zstd pkgs.makeWrapper ];
                    unpackPhase = ''
                      runHook preUnpack
                      unzip -qq $src
                      zstd -d -q pkg-*.tar.zst -o pkg.tar
                      mkdir -p unpacked && tar -xf pkg.tar -C unpacked
                      runHook postUnpack
                    '';
                    sourceRoot = "unpacked";
                    installPhase = ''
                      runHook preInstall
                      mkdir -p $out/lib $out/bin
                      cp -r site-packages $out/lib/
                      makeWrapper ${py}/bin/python $out/bin/mblack \
                        --add-flags "-m mblack" \
                        --prefix PYTHONPATH : $out/lib/site-packages
                      runHook postInstall
                    '';
                  };
              in
              pkgs.stdenv.mkDerivation rec {
                pname = "mojo";
                version = "1.0.0";
                src = pkgs.fetchurl {
                  url = "https://conda.modular.com/max/linux-64/mojo-compiler-${version}-release.conda";
                  hash = "sha256-Q5TGFG1H7HeUqaPtV3WuFY9Z+D+OGu1ZQIsXxJCYIbM=";
                };
                # A .conda is a zip of zstd-compressed tarballs; the payload is the pkg- one.
                nativeBuildInputs = [
                  pkgs.autoPatchelfHook pkgs.unzip pkgs.zstd pkgs.makeWrapper
                ];
                buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.ncurses ];
                unpackPhase = ''
                  runHook preUnpack
                  unzip -qq $src
                  zstd -d -q pkg-*.tar.zst -o pkg.tar
                  mkdir -p unpacked && tar -xf pkg.tar -C unpacked
                  runHook postUnpack
                '';
                sourceRoot = "unpacked";
                installPhase = ''
                  runHook preInstall
                  mkdir -p $out
                  cp -r bin lib share $out/

                  # conda records the install prefix in modular.cfg, padded out so it can be
                  # rewritten on install. Left alone, mojo looks for its own standard library on
                  # Modular's build machine and reports "unable to locate module 'std'".
                  prefix=$(sed -n 's/^package_root = //p' $out/share/max/modular.cfg | head -1)
                  substituteInPlace $out/share/max/modular.cfg --replace-quiet "$prefix" "$out"

                  # mojo resolves its formatter through that file's mblack_path, which points here
                  # rather than at $PATH -- so the separate formatter package is linked in.
                  ln -s ${mblack}/bin/mblack $out/bin/mblack

                  # mojo reads $MODULAR_HOME/modular.cfg -- at the root, not under share/max -- and
                  # wants to write a cache beside it. The store is read only, so the wrapper points
                  # MODULAR_HOME at a per-user directory seeded from this one on first run. The
                  # directory is named after this exact build, so a new compiler does not inherit
                  # the previous one's paths into a store path that is no longer there.
                  mv $out/bin/mojo $out/bin/.mojo-unwrapped
                  makeWrapper $out/bin/.mojo-unwrapped $out/bin/mojo \
                    --run 'home="''${XDG_CACHE_HOME:-$HOME/.cache}/mojo/$(basename @out@)"; if [ ! -f "$home/modular.cfg" ]; then mkdir -p "$home"; sed "s|^cache_dir = .*|cache_dir = $home/cache|" @out@/share/max/modular.cfg > "$home/modular.cfg"; fi; export MODULAR_HOME="$home"'
                  substituteInPlace $out/bin/mojo --replace-quiet "@out@" "$out"
                  runHook postInstall
                '';
                meta = {
                  description = "Mojo compiler, from Modular's conda channel";
                  license = pkgs.lib.licenses.unfree;
                };
              }
            )]],
})
