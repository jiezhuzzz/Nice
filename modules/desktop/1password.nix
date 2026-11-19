# 1Password CLI + GUI. The GUI enables the system-auth polkit helper and
# the browser integration socket; polkitPolicyOwners is the list of users
# allowed to unlock via system auth.
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
