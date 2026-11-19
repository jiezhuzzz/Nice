{
  den.aspects.desktop."1password" = {user, ...}: {
    nixos = {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [user.userName];
      };
    };
  };
}
