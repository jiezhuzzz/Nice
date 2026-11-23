# The one home that receives a forwarded agent (the `cc` blocks in
# modules/ssh/ssh.nix), which is also what holds its signing key.
{den, ...}: {
  den.aspects.chameleon = {
    includes = [den.aspects.standalone den.aspects.git-signing];

    # ForwardAgent's per-connection $SSH_AUTH_SOCK dies on disconnect, while
    # long-lived zellij panes keep the old value. .profile runs before .bashrc, so
    # it still sees the real socket.
    homeManager.programs.bash = {
      profileExtra = ''
        if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]; then
          ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
        fi
      '';
      bashrcExtra = ''
        [ -S "$HOME/.ssh/agent.sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
      '';
    };
  };
}
