# Only for hosts that decrypt secrets to /run/agenix: a detached zellij/shpool
# outlives the forwarded agent, so signing reads the key file instead.
{den, ...}: {
  den.aspects.git-agentless-signing = {
    includes = [den.aspects.git-signing];
    homeManager = {osConfig, ...}: {
      programs.git.settings.user.signingkey = osConfig.age.secrets.git-signing-key.path;
    };
  };
}
