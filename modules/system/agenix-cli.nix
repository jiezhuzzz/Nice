{
  den.aspects.agenix-cli.os = {inputs', ...}: {
    environment.systemPackages = [inputs'.agenix.packages.default];
  };
}
