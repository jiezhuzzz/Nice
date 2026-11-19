{inputs, ...}: {
  imports = [
    inputs.flake-file.flakeModules.dendritic
    inputs.den.flakeModules.dendritic
  ];

  flake-file = {
    description = "A nice configuration (laptop, mac, server, nas)";
    formatter = pkgs: pkgs.alejandra;

    inputs = {
      den.url = "github:denful/den/latest";

      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      # den's darwin builder reads nix-darwin by this name.
      darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
