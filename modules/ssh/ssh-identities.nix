{nice, ...}: {
  den.aspects.ssh-identities.homeManager = {osConfig, ...}: let
    key = name: osConfig.age.secrets.${name}.path;
  in {
    programs.ssh.settings."github.com" = {
      IdentityFile = key "github-ssh-key";
      IdentitiesOnly = true;
      # A stale forwarded $SSH_AUTH_SOCK makes every `git@github.com` operation
      # hang instead of using the key.
      IdentityAgent = "none";
    };
    # One identity registered on both github.com and the forge.
    programs.ssh.settings.${nice.facts.forge.host} = {
      IdentityFile = key "github-ssh-key";
      IdentitiesOnly = true;
      IdentityAgent = "none";
    };
    programs.ssh.settings."tacc 129.114.108.129" = {
      IdentityFile = key "chameleon-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."10.52.*.*" = {
      IdentityFile = key "chameleon-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."uc 192.5.87.20" = {
      IdentityFile = key "chameleon-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."10.140.*.*" = {
      IdentityFile = key "chameleon-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."uchicago" = {
      HostName = "linux.cs.uchicago.edu";
      User = "jiezhu";
      IdentityFile = key "lab-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."goku vegeta" = {
      ProxyJump = "uchicago";
      User = "jiezzz";
      IdentityFile = key "lab-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."nixmachine" = {
      HostName = "nixmachine.taile3de9d.ts.net";
      User = "jie";
      IdentityFile = key "home-ssh-key";
      IdentitiesOnly = true;
    };
    programs.ssh.settings."192.168.86.*" = {
      User = "jie";
      IdentityFile = key "home-ssh-key";
      IdentitiesOnly = true;
    };
  };
}
