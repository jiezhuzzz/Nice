{
  lib,
  nice,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (nice) fixed;

  appearance = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.nice) theme;
    cfg = config.nice.appearance;
    pairOf = type: types.submodule {options = theme.pair (_: mkOption {inherit type;});};
  in {
    options.nice.appearance = {
      env = mkOption {
        type = types.attrsOf (pairOf types.str);
        default = {};
      };
      exports = fixed types.raw (theme.pair (variant: lib.mapAttrs (_: value: value.${variant.appearance}) cfg.env));
      wrap = fixed types.raw (package: args:
        pkgs.symlinkJoin {
          inherit (package) pname version meta;
          paths = [package];
          postBuild = ''
            ln -sf ${pkgs.writeShellScript "${package.pname}-appearance" ''
              case ''${NICE_APPEARANCE-} in
                light) exec ${lib.getExe package} ${lib.escapeShellArgs args.light} "$@" ;;
                *) exec ${lib.getExe package} ${lib.escapeShellArgs args.dark} "$@" ;;
              esac
            ''} $out/bin/${package.meta.mainProgram}
          '';
        });
    };

    config = {
      nice.appearance.env.NICE_APPEARANCE = theme.pair (variant: variant.appearance);
      # A process that no interactive shell started never learns the terminal's
      # appearance.
      home.sessionVariables = cfg.exports.dark;
    };
  };
in {
  den.default.homeManager.imports = [appearance];
}
