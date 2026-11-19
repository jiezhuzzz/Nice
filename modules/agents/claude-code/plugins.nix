{inputs, ...}: {
  flake-file.inputs = {
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    claude-plugins-community = {
      url = "github:anthropics/claude-plugins-community";
      flake = false;
    };

    caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    # Source for individual skills, not the plugin: only the subdirectories
    # named below and in pi.nix are linked.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
  };

  den.aspects.claude-code.plugins.homeManager = let
    # Anthropic's marketplace, pinned in flake.lock (see above). One repo of
    # ~35 plugins; everything below is a subdirectory of it, so there is exactly
    # one thing to update.
    officialPlugins = "${inputs.claude-plugins-official}/plugins";

    communityPlugins = inputs.claude-plugins-community;
  in {
    # Each entry is linked whole as ~/.config/claude/skills/<name> and loaded as
    # a personal plugin, so its skills, agents, commands and hooks all register
    # — namespaced under the attribute name. An attribute set rather than a
    # list: the name becomes that directory, where the list form derives it from
    # the store path and yields churn like `bxa1s0m3h4sh-source`.
    #
    # Anything else from the marketplace is a one-liner away; `ls
    # ${officialPlugins}` lists all ~35.
    programs.claude-code.plugins = {
      claude-code-setup = "${officialPlugins}/claude-code-setup";
      code-simplifier = "${officialPlugins}/code-simplifier";
      feature-dev = "${officialPlugins}/feature-dev";
      eli5 = "${communityPlugins}/eli5";
      inherit (inputs) caveman ponytail;
    };

    # Single skills, linked as ~/.config/claude/skills/<name> without their
    # plugin: only the named directory comes along, so sibling skills the text
    # mentions (`superpowers:test-driven-development`) are not installed.
    programs.claude-code.skills = {
      systematic-debugging = "${inputs.superpowers}/skills/systematic-debugging";
    };
  };
}
