{
  config,
  den,
  lib,
  nice,
  ...
}: let
  output = entity: lib.getAttrFromPath entity.intoAttr config.flake;
  toplevelOf = system: system.config.system.build.toplevel;

  toplevel = entity:
    if entity.class == "homeManager"
    then (output entity).activationPackage
    else toplevelOf (output entity);

  parkedCodex = toplevelOf ((output den.hosts.x86_64-linux.nixps).extendModules {modules = [{home-manager.users.${nice.user.name}.imports = [(den.lib.aspects.resolve "homeManager" den.aspects.codex)];}];});
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    evalOnly = name: drv: pkgs.writeText "eval-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
    evalAll = prefix: lib.mapAttrs' (name: entity: lib.nameValuePair "${prefix}-${name}" (evalOnly name (toplevel entity)));
  in {
    checks =
      evalAll "host" (den.hosts.${system} or {} // den.homes.${system} or {})
      // lib.optionalAttrs (system == "x86_64-linux") (
        evalAll "eval" (den.hosts.aarch64-darwin or {})
        // {
          agenix-rules = pkgs.writeText "agenix-rules.json" (builtins.toJSON config.flake.lib.agenixRules);
          parked-codex = evalOnly "parked-codex" parkedCodex;
          caddy = (output den.hosts.x86_64-linux.nixmachine).config.services.caddy.package;
        }
      );
  };
}
