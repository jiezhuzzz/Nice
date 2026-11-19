{
  lib,
  withSystem,
  ...
}: {
  den.schema.home = {
    imports = [
      ({config, ...}: {
        options.homeDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/${config.userName}";
        };
        config.pkgs = withSystem config.system ({pkgs, ...}: pkgs);
      })
    ];
    includes = [
      ({home, ...}: {
        homeManager.home = {
          username = home.userName;
          inherit (home) homeDirectory;
        };
      })
    ];
  };
}
