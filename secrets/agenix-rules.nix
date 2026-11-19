# Read by the agenix CLI run from this directory. getFlake sees only tracked
# files: `git add` a new host before `agenix -r`.
(builtins.getFlake (toString ../.)).lib.agenixRules
