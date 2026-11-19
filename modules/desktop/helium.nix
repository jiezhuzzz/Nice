{
  den.aspects.desktop.helium.homeManager = {pkgs, ...}: {
    # Helium: Chromium with Google integration stripped (the ungoogled patch set)
    # plus imputnet's own privacy work and a bundled uBlock Origin. Replaces
    # ungoogled-chromium here. The binary is `helium`, which is what the niri
    # Alt+B bind spawns and what the xremap Cmd-key rule matches on.
    #
    # The derivation is vendored in pkgs/helium/package.nix rather than pulled
    # from a flake input; see the comment there for why.
    #
    # home-manager's `programs.chromium` is deliberately unused: it applies flags
    # by way of `package.override { commandLineArgs = ...; }`, which this package
    # does not take, and it writes extensions and policies into ~/.config/chromium,
    # which Helium does not read (it uses ~/.config/helium).
    home.packages = [
      (pkgs.helium.override {
        flags = [
          "--force-device-scale-factor=1.25"
          # Under native Wayland, Chromium ignores GTK_IM_MODULE/XMODIFIERS and only
          # talks to fcitx5 via the text-input protocol, which it does not enable by
          # default. Without this flag Rime can't be switched to at all. Pin v3 to
          # avoid the buggy v1 path some compositors negotiate (niri supports v3).
          "--enable-wayland-ime"
          "--wayland-text-input-version=3"
        ];
      })
    ];
  };
}
