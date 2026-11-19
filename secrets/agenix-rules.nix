# Read by the agenix CLI: run it from this directory, `agenix -e ssh/github.age`
# (the devShell provides the locked agenix). The rules are the flake's
# lib.agenixRules (modules/den/secrets.nix), derived from the secrets each host
# declares, so only tracked files count: `git add` a new host before `agenix -r`.
(builtins.getFlake (toString ../.)).lib.agenixRules
