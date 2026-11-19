{
  den.aspects.firmware.nixos = {
    hardware.enableAllFirmware = true;
    services.fwupd.enable = true;
  };
}
