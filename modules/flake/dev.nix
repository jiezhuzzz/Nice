{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  flake-file.inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem = {
    config,
    inputs',
    pkgs,
    ...
  }: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.statix.enable = true;
      programs.shellcheck.enable = true;
      programs.shfmt.enable = true;
      programs.actionlint.enable = true;
    };

    devShells.default = pkgs.mkShellNoCC {
      packages = [
        pkgs.nil
        pkgs.alejandra
        config.treefmt.build.wrapper
        inputs'.agenix.packages.default
      ];
    };
  };
}
