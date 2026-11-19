# Import only where a key source exists (an agent holding the key, or the
# agenix file that git-agentless-signing.nix points at), or every commit fails
# to sign.
{nice, ...}: {
  den.aspects.git-signing.homeManager = {lib, ...}: {
    programs.git.settings = {
      # key:: prefix tells git to find the matching private key in the
      # SSH agent — works with agent forwarding and local agents alike.
      user.signingkey = lib.mkDefault "key::${nice.user.signingKey}";
      gpg.format = "ssh";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };
}
