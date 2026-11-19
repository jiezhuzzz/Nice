# Agent-free git signing for headless hosts: point the signing key at its
# agenix-decrypted file instead of the SSH agent, so `git commit -S` survives a
# detached tmux/shpool. The key is unchanged, so the existing allowedSigners
# still verifies these signatures. The matching ssh auth pinning for github and
# the forge lives in modules/ssh/ssh-identities.nix, which these hosts also
# include. Only for hosts that decrypt the secrets to /run/agenix.
{den, ...}: {
  den.aspects.git-agentless-signing = {
    includes = [den.aspects.git-signing];
    homeManager = {osConfig, ...}: {
      programs.git.settings.user.signingkey = osConfig.age.secrets.git-signing-key.path;
    };
  };
}
