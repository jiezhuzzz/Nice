{
  keywords = ["nix-env" "profile"];
  deny = [
    "Bash(nix-env -i*)"
    "Bash(nix-env --install*)"
    "Bash(nix profile install*)"
    "Bash(nix profile add*)"
  ];
  script.Bash = ''
    if [[ "$cmd" =~ $sep"nix-env"[[:space:]] ]] && [[ "$cmd" =~ [[:space:]](-i|-iA|-ie|--install)([[:space:]]|$) ]]; then
      deny "nix-env installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild. Do not substitute curl-pipe-sh or a download into ~/.local/bin either."
    fi

    if [[ "$cmd" =~ $sep"nix"[[:space:]]+profile[[:space:]]+(add|install)([[:space:]]|$) ]]; then
      deny "'nix profile' installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild."
    fi
  '';
}
