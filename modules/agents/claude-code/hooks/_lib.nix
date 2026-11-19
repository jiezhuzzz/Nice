{pkgs}: let
  inherit (pkgs) lib;
in {
  # Verified against claude-code 2.1.222: a PreToolUse hook is consulted before
  # the permission rules, so its reason is what the model sees; each guard's
  # `deny` list is only a backstop for a hook that errors and fails open.
  #
  # Deny rather than rewrite via updatedInput: a rewrite leaves the agent
  # reading output from a command it did not write.
  #
  # `keywords` must be a superset of what the checks in `text` can match.
  mkGuardHook = name: keywords: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.jq];
      text =
        ''
          input=$(cat)

          case "$input" in
            ${lib.concatMapStringsSep " | " (k: "*${lib.escapeShellArg k}*") keywords}) ;;
            *) exit 0 ;;
          esac

          deny() {
            jq -nc --arg reason "$1" \
              '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
            exit 0
          }
        ''
        + text;
    };

  # `sep` anchors to command position so a guard does not match its own advice,
  # such as `uv run python -c ...`.
  commandGuardPreamble = ''
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
    sep='(^|[;&|(])[[:space:]]*'
  '';
}
