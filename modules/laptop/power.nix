{
  den.aspects.laptop.power.nixos = {
    services.logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
      HandleLidSwitchDocked = "ignore";
      HandleSuspendKey = "lock";
    };

    powerManagement.enable = true;
    services.thermald.enable = true;

    # noctalia-shell's battery widget reads power state over UPower, not sysfs.
    services.upower.enable = true;
    services.power-profiles-daemon.enable = false;
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };
}
