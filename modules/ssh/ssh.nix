{nice, ...}: {
  den.aspects.ssh.homeManager = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
      settings."github.com" = {
        HostName = "github.com";
        User = "git";
      };
      # Forgejo runs its own SSH server; without the port, the short
      # `git.jiezhu.me:jie/repo` form would hit :22 and land on nixmachine's shell
      # account.
      settings.${nice.facts.forge.host} = {
        User = "git";
        Port = nice.facts.forge.sshPort;
      };
      # Only Chameleon forwards the agent: forwarding elsewhere leaves a stale
      # $SSH_AUTH_SOCK when the session drops, which then hangs github auth.
      settings."tacc 129.114.108.129" = {
        HostName = "129.114.108.129";
        User = "cc";
        ForwardAgent = true;
      };
      settings."10.52.*.*" = {
        User = "cc";
        ProxyJump = "tacc";
        ForwardAgent = true;
      };
      # The alias carries the bare floating IP so `ssh cc@<floating-ip>` matches
      # too. It is reattached to whichever node is the current bastion; change
      # both copies together if the project gets a new one.
      settings."uc 192.5.87.20" = {
        HostName = "192.5.87.20";
        User = "cc";
        ForwardAgent = true;
      };
      settings."10.140.*.*" = {
        User = "cc";
        ProxyJump = "uc";
        ForwardAgent = true;
      };
    };
  };
}
