# gamescope direct scanout can defeat KMS capture (black frame); the fix is
# forcing composition on the hardware.
{
  den.aspects.gaming.sunshine.nixos = {
    services.sunshine = {
      enable = true;
      openFirewall = true;
      capSysAdmin = true;
      autoStart = true;
    };
  };
}
