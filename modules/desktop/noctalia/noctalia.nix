{
  den,
  inputs,
  ...
}: {
  # `follows` keeps one nixpkgs flake-wide, so upstream's binary cache can never
  # serve this build; it builds locally.
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.desktop.noctalia = {
    includes = [den.aspects.desktop.noctalia._];

    homeManager.imports = [inputs.noctalia.homeModules.default];
  };
}
