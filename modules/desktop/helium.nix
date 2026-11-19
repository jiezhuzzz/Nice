{
  den.aspects.desktop.helium.homeManager = {pkgs, ...}: {
    # home-manager's `programs.chromium` is deliberately unused: it applies flags
    # by way of `package.override { commandLineArgs = ...; }`, which this package
    # does not take, and it writes extensions and policies into ~/.config/chromium,
    # which Helium does not read (it uses ~/.config/helium).
    home.packages = [
      (pkgs.helium.override {
        flags = [
          "--force-device-scale-factor=1.25"
          # Under native Wayland, Chromium reaches fcitx5 only via text-input,
          # which is off by default. Pin v3 to avoid the buggy v1 path.
          "--enable-wayland-ime"
          "--wayland-text-input-version=3"
        ];
      })
    ];
  };
}
