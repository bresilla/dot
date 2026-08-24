local wing = require("wing")

-- Carbon has no released toolchain in nixpkgs: upstream ships prebuilt nightlies and nothing else,
-- so the dev shell builds one from the published tarball. The version and hash below are a pin --
-- `make toolchain` moves them to the newest nightly.
wing.template("carbon", {
  description = "Carbon CLI app with .make.lua, flake.nix, tests, and release hooks",
  language = "carbon",
  framework = "cli",
  tags = { "builtin", "carbon", "cli" },
  environment = "The dev shell builds a pinned Carbon nightly toolchain from upstream's release " ..
                "tarball; `make toolchain` moves the pin to the newest one.",
  nix_packages = [[
            (pkgs.stdenv.mkDerivation rec {
              pname = "carbon-toolchain";
              version = "0.0.0-0.nightly.2026.08.23";
              src = pkgs.fetchurl {
                url = "https://github.com/carbon-language/carbon-lang/releases/download/v${version}/carbon_toolchain-${version}.tar.gz";
                hash = "sha256-OEELq48XfzgbZf5zc9zR3umetFY7c8IJRGw+0mREqpg=";
              };
              # A release tarball built elsewhere: its interpreter and RPATH point at paths that do
              # not exist here, and autoPatchelfHook rewrites them to the store's.
              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs = [ pkgs.stdenv.cc.cc.lib ];
              sourceRoot = "carbon_toolchain-${version}";
              installPhase = ''
                runHook preInstall
                mkdir -p $out
                cp -r bin lib $out/
                runHook postInstall
              '';
              meta.description = "Carbon toolchain, prebuilt nightly";
            })]],
})
