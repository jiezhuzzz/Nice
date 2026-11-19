{
  den,
  nice,
  ...
}: {
  den.aspects.${nice.user.name} = {
    includes = [
      den.batteries.define-user
      den.batteries.primary-user
    ];

    provides.to-hosts = {user, ...}: {
      nixos.nix.settings.trusted-users = [user.userName];

      darwin.users = {
        knownUsers = [user.userName];
        users.${user.userName}.uid = 501;
      };
    };
  };
}
