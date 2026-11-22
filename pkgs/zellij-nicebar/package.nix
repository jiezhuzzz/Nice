{
  lib,
  pkgsCross,
  runCommand,
}: let
  wasm = pkgsCross.wasm32-wasip1;

  unwrapped = wasm.rustPlatform.buildRustPackage {
    pname = "nicebar";
    inherit ((lib.importTOML ./nicebar/Cargo.toml).workspace.package) version;
    src = ./nicebar;
    cargoLock.lockFile = ./nicebar/Cargo.lock;
    cargoBuildFlags = ["--package=nicebar"];
    # Mirrors nixpkgs' zellijPlugins until NixOS/nixpkgs#463720 lets the
    # wasm32-wasip1 cross toolchain link on its own.
    nativeBuildInputs = [wasm.buildPackages.lld];
    env.RUSTFLAGS = "-C linker=wasm-ld";
    doCheck = false;
  };
in
  # programs.zellij.plugins links each package itself as plugins/<name>.wasm,
  # so the package must be the bare file.
  runCommand "zellij-nicebar-${unwrapped.version}.wasm" {
    pname = "zellij-nicebar";
    inherit (unwrapped) version;
    passthru = {inherit unwrapped;};
    meta = {
      description = "Zellij status bar with mode, session, tabs and CPU/GPU/memory usage";
      license = lib.licenses.mit;
    };
  } ''
    cp ${unwrapped}/bin/nicebar.wasm $out
  ''
