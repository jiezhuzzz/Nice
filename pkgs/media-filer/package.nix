{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "media-filer";
  version = "0.1.0";
  pyproject = true;
  src = ./filer;
  build-system = [python3.pkgs.hatchling];
  dependencies = [python3.pkgs.guessit];
  nativeCheckInputs = [python3.pkgs.pytestCheckHook];
  meta.platforms = lib.platforms.linux;
}
