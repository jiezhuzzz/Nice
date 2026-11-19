{den, ...}: {
  den.aspects.server.includes = with den.aspects; [
    core
    bash
    oh-my-posh
    tmux
    rclone
    shpool
  ];
}
