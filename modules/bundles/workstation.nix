{den, ...}: {
  den.aspects.workstation.includes = with den.aspects; [
    core
    fish
    zed
    rime
    ghostty
    ssh-identities
    ssh-agent-keys
    git-signing
    agenix-cli
  ];
}
