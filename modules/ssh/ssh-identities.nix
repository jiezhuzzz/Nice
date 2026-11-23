{nice, ...}: {
  den.aspects.ssh-identities.homeManager = {osConfig, ...}: let
    identity = secret: {
      IdentityFile = osConfig.age.secrets.${secret}.path;
      IdentitiesOnly = true;
    };
    # A stale forwarded $SSH_AUTH_SOCK makes every `git@github.com` operation
    # hang instead of using the key.
    forge = identity "github-ssh-key" // {IdentityAgent = "none";};
    chameleon = identity "chameleon-ssh-key";
    lab = identity "lab-ssh-key";
    home = identity "home-ssh-key" // {User = nice.user.name;};
  in {
    programs.ssh.settings = {
      "github.com" = forge;
      # One identity registered on both github.com and the forge.
      ${nice.facts.forge.host} = forge;
      "tacc 129.114.108.129" = chameleon;
      "10.52.*.*" = chameleon;
      "uc 192.5.87.20" = chameleon;
      "10.140.*.*" = chameleon;
      uchicago =
        lab
        // {
          HostName = "linux.cs.uchicago.edu";
          User = "jiezhu";
        };
      "goku vegeta" =
        lab
        // {
          ProxyJump = "uchicago";
          User = "jiezzz";
        };
      nixmachine = home // {HostName = "nixmachine.taile3de9d.ts.net";};
      "192.168.86.*" = home;
    };
  };
}
