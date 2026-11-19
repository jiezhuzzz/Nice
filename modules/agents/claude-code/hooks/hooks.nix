{
  den.aspects.claude-code.hooks.homeManager = {
    lib,
    pkgs,
    ...
  }: let
    inherit (import ./_lib.nix {inherit pkgs;}) mkGuardHook commandGuardPreamble;

    guards = [
      (import ./_uv-only.nix)
      (import ./_nix-declarative.nix)
      (import ./_flake-lock.nix)
      (import ./_github-via-gh.nix {inherit lib;})
    ];

    matchers = lib.unique (lib.concatMap (guard: lib.attrNames guard.script) guards);

    # `deny` exits, so the first matching guard in `guards` wins.
    hookFor = matcher: let
      members = lib.filter (guard: guard.script ? ${matcher}) guards;
      name = "claude-${lib.toLower (lib.replaceStrings ["|"] ["-"] matcher)}-guard";
      keywords = lib.unique (lib.concatMap (guard: guard.keywords) members);
      text =
        lib.optionalString (matcher == "Bash") commandGuardPreamble
        + lib.concatMapStringsSep "\n" (guard: guard.script.${matcher}) members;
    in {
      inherit matcher;
      hooks = [
        {
          type = "command";
          command = lib.getExe (mkGuardHook name keywords text);
          timeout = 5;
        }
      ];
    };
  in {
    programs.claude-code.settings = {
      hooks.PreToolUse = map hookFor matchers;
      permissions.deny = lib.concatMap (guard: guard.deny) guards;
    };
  };
}
