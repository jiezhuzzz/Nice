{den, ...}: {
  den.aspects.workstation.includes = with den.aspects; [
    core
    fish
    zed
    rime
    ghostty
    rio
    ssh-identities
    ssh-agent-keys
    git-signing
    agenix-cli
  ];
}
