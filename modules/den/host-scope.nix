# den walks a host's own aspect tree in host scope, which delivers only the
# system classes: a homeManager or user definition there is dropped without a
# warning.
{
  den,
  lib,
  ...
}: let
  walked = ctx:
    (den.lib.capture.captureWithPathsWith {
      classes = ["homeManager" "user"];
      root = ctx.host.aspect;
      inherit ctx;
    }).entries;

  misplaced = host: let
    contexts = [{inherit host;}] ++ map (user: {inherit host user;}) (lib.attrValues host.users);
    dropped = lib.filter (entry: entry.hasClass && !entry.excluded) (lib.concatMap walked contexts);
  in
    lib.unique (map (entry: "${entry.name} (${entry.class})") dropped);
in {
  den.schema.host.includes = [
    ({host, ...}: {
      os.assertions =
        map (found: {
          assertion = false;
          message = "${found} sits in ${host.name}'s own scope, which drops it: move it under provides.to-users.";
        })
        (misplaced host);
    })
  ];
}
