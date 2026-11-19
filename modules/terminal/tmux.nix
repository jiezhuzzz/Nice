{
  den.aspects.tmux.homeManager = {pkgs, ...}: let
    tmcl = "${pkgs.tmux-mem-cpu-load}/bin/tmux-mem-cpu-load -g 0 -m 2 -a 0 -i 2";
    memScript = pkgs.writeShellScript "tmux-mem" ''
      set -- $(${tmcl})
      printf '%s' "$1"
    '';
    cpuScript = pkgs.writeShellScript "tmux-cpu" ''
      set -- $(${tmcl})
      printf '%s' "$2"
    '';
  in {
    programs.tmux = {
      enable = true;
      mouse = true;
      terminal = "tmux-256color";
      baseIndex = 1;
      escapeTime = 0;
      historyLimit = 10000;
      keyMode = "vi";
      extraConfig = ''
        set -ga terminal-overrides ",*256col*:Tc,xterm-ghostty:Tc"

        set -g focus-events on

        # extended-keys-format needs tmux >= 3.5. Takes effect only on a fresh
        # server: `tmux kill-server`.
        set -g extended-keys on
        set -g extended-keys-format csi-u

        set -g pane-base-index 1
        set -g renumber-windows on
        set -g detach-on-destroy off

        set -g status-left "#{?#{m:*[!0-9]*,#{session_name}},[#{session_name}] ,}"

        set -g status-right-length 100
        set -g status-right "#{E:@catppuccin_status_host}"

        set -g set-clipboard on
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-pipe-and-cancel

        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5

        bind c new-window -c "#{pane_current_path}"
      '';
    };

    catppuccin.tmux.extraConfig = ''
      set -g @catppuccin_window_status_style "rounded"

      set -g @catppuccin_window_text " #{b:pane_current_path}:#{pane_current_command}"
      set -g @catppuccin_window_current_text " #{b:pane_current_path}:#{pane_current_command}"

      set -g @catppuccin_host_text "  #(${cpuScript})   #(${memScript})  #H"
    '';
  };
}
