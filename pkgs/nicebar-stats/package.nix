{
  lib,
  rustPlatform,
  zellij-nicebar,
}:
rustPlatform.buildRustPackage {
  pname = "nicebar-stats";
  inherit (zellij-nicebar.unwrapped) version src cargoDeps;
  cargoBuildFlags = ["--package=nicebar-stats"];
  cargoTestFlags = ["--package=nicebar-core" "--package=nicebar-stats"];
  meta = {
    description = "One-shot CPU/GPU/memory sampler for the nicebar Zellij plugin";
    license = lib.licenses.mit;
    mainProgram = "nicebar-stats";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
