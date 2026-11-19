{
  den.aspects.cargo.homeManager = {config, ...}: {
    home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
  };
}
