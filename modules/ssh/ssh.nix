# SSH client config — base settings shared by all hosts.
# Hosts with agenix-decrypted keys also pin identity files (ssh-identities.nix).
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
      # The homelab forge (modules/homelab/forgejo/forge.nix). A separate
      # port because git is served by Forgejo's own SSH server rather than the
      # host's sshd — without it the short `git.jiezhu.me:jie/repo` form would
      # hit :22 and land on nixmachine's shell account. Identity pinning lives in
      # ssh-identities.nix.
      settings.${nice.facts.forge.host} = {
        User = "git";
        Port = nice.facts.forge.sshPort;
      };
      # Chameleon (user `cc`) is the ONLY place we forward the agent: you hop
      # from the tacc gateway onto reserved bare-metal nodes (10.52.*.*) and use
      # your keys there. No other host forwards — see ssh-identities.nix for why.
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
      # The CHI@UC half of the same setup. Like tacc, the alias carries the bare
      # IP too, so `ssh cc@<floating-ip>` picks up the identity instead of falling
      # through to `Host *`. Both are the project's floating IP, reattached to
      # whichever node is the current bastion — change them together if the
      # project gets a new one.
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
