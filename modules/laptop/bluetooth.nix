{
  den.aspects.laptop.bluetooth.nixos = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;

      # BlueZ gates its D-Bus battery interface behind this flag.
      settings.General.Experimental = true;
    };
  };
}
