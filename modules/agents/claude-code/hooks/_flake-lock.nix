{
  keywords = ["flake.lock"];
  # Edit() alone — file rules match every editing tool, so a Write() entry is
  # redundant and warns at startup.
  deny = ["Edit(**/flake.lock)"];
  script."Edit|Write" = ''
    path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

    case "$path" in
      */flake.lock | flake.lock)
        deny "flake.lock is generated — never edit it by hand, since each entry carries a narHash that will no longer match. Regenerate it instead: 'nix flake update' rewrites every input, 'nix flake update <input>' bumps just one (for example 'nix flake update nixpkgs'). To change where an input points, edit its declaration and let the lock follow: the inputs block in flake.nix, or, where flake-file generates flake.nix, the module's flake-file.inputs entry followed by 'nix run .#write-flake'."
        ;;
    esac
  '';
}
