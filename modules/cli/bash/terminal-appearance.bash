# shellcheck shell=bash

# Prints `light` or `dark` from the terminal's background color (OSC 11), and
# fails when the terminal reports none. The cursor position report that follows
# is a sentinel: every terminal answers it, and after the color, so a terminal
# without OSC 11 costs no timeout.
terminal_appearance() {
  local reply luma
  [[ -t 0 && ${TERM-dumb} != dumb ]] || return 1
  # Keys typed ahead of the prompt would be read as part of the reply and lost.
  if read -r -t 0 </dev/tty; then
    return 1
  fi
  printf '\e]11;?\e\\\e[6n' >/dev/tty
  IFS= read -r -s -d R -t 1 reply </dev/tty || return 1
  [[ $reply =~ \]11\;rgba?:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]] || return 1
  luma=$((299 * 16#${BASH_REMATCH[1]:0:2} + 587 * 16#${BASH_REMATCH[2]:0:2} + 114 * 16#${BASH_REMATCH[3]:0:2}))
  if ((luma > 1000 * 255 / 2)); then
    echo light
  else
    echo dark
  fi
}
