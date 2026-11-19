# Soft guidance injected into every session — Claude Code's user-level
# CLAUDE.md equivalent.
{nice, ...}: {
  den.aspects.claude-code.context.homeManager = {
    programs.claude-code.context = nice.agents.context;
  };
}
