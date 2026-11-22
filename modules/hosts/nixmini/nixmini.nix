{den, ...}: {
  den.aspects.nixmini = {
    includes = [den.aspects.darwin-workstation];
  };
}
