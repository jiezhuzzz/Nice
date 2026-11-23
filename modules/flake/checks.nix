{
  config,
  den,
  lib,
  nice,
  ...
}: let
  output = entity: lib.getAttrFromPath entity.intoAttr config.flake;
  extend = entity: modules: (output entity).extendModules {inherit modules;};
  toplevelOf = system: system.config.system.build.toplevel;

  toplevel = entity:
    if entity.class == "homeManager"
    then (output entity).activationPackage
    else toplevelOf (output entity);

  parkedCodex = toplevelOf (extend den.hosts.x86_64-linux.nixps [{home-manager.users.${nice.user.name}.imports = [(den.lib.aspects.resolve "homeManager" den.aspects.codex)];}]);
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    evalOnly = name: drv: pkgs.writeText "eval-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
    entities = den.hosts.${system} or {} // den.homes.${system} or {};
  in {
    checks =
      lib.mapAttrs' (name: entity: lib.nameValuePair "host-${name}" (evalOnly name (toplevel entity))) entities
      // lib.optionalAttrs (system == "x86_64-linux") (
        lib.mapAttrs' (name: mac: lib.nameValuePair "eval-${name}" (evalOnly name (toplevel mac))) den.hosts.aarch64-darwin or {}
        // {
          agenix-rules = pkgs.writeText "agenix-rules.json" (builtins.toJSON config.flake.lib.agenixRules);
          parked-codex = evalOnly "parked-codex" parkedCodex;
          caddy = (output den.hosts.x86_64-linux.nixmachine).config.services.caddy.package;
        }
      );
  };
}
