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

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
  };

  den.aspects.claude-code.plugins.homeManager = let
    officialPlugins = "${inputs.claude-plugins-official}/plugins";

    communityPlugins = inputs.claude-plugins-community;
  in {
    # An attribute set rather than a list: the list form derives each directory
    # name from the store path and yields churn like `bxa1s0m3h4sh-source`.
    programs.claude-code.plugins = {
      claude-code-setup = "${officialPlugins}/claude-code-setup";
      code-simplifier = "${officialPlugins}/code-simplifier";
      feature-dev = "${officialPlugins}/feature-dev";
      eli5 = "${communityPlugins}/eli5";
      inherit (inputs) caveman ponytail;
    };

    # Sibling skills the text mentions (`superpowers:test-driven-development`)
    # are not installed.
    programs.claude-code.skills = {
      systematic-debugging = "${inputs.superpowers}/skills/systematic-debugging";
    };
  };
}
