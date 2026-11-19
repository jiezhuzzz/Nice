# Helium (https://helium.computer) — imputnet's Chromium fork: the same
# de-Googling ungoogled-chromium does, plus their own privacy patches and a
# bundled uBlock Origin.
#
# Vendored here instead of taken from one of the community flakes: Helium is
# not in nixpkgs (the packaging PR has been open a long while), and every flake
# that packages it does exactly what this file does. Carrying the ~200 lines
# ourselves costs less than an input that can move under us.
#
# This repacks upstream's prebuilt .deb — there is no source build on offer,
# imputnet ships binaries only. So the trust story is upstream's release
# artifacts either way; vendoring only moves who owns the packaging.
#
# Updating: bump `version`, then refresh both hashes with
#   nix store prefetch-file --hash-type sha256 <url>
# Both, even though only x86_64 hosts use this today — a wrong arm64 hash is a
# silent trap for whoever first builds on aarch64.
{
  lib,
  stdenv,
  fetchurl,
  binutils,
  patchelf,
  makeWrapper,
  wrapGAppsHook3,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  adwaita-icon-theme,
  nss,
  nspr,
  libGL,
  libgbm,
  libdrm,
  libxkbcommon,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libXrender,
  libxcb,
  libxshmfence,
  libXi,
  libXcursor,
  libXft,
  libXScrnSaver,
  libXtst,
  libXt,
  libSM,
  libICE,
  alsa-lib,
  dbus,
  cups,
  ffmpeg,
  libva,
  pipewire,
  wayland,
  vulkan-loader,
  systemd,
  udev,
  xdg-utils,
  coreutils,
  pango,
  cairo,
  gdk-pixbuf,
  atk,
  at-spi2-atk,
  at-spi2-core,
  freetype,
  fontconfig,
  libuuid,
  expat,
  zlib,
  libxml2,
  libkrb5,
  snappy,
  # Flags baked into the wrapper, one per list entry. Upstream also reads
  # ~/.config/helium-flags.conf, but that is imperative state; prefer this.
  flags ? [],
}: let
  version = "0.14.9.1";

  # Upstream names the .deb by Debian arch, not by Nix system string.
  arches = {
    x86_64-linux = {
      suffix = "amd64";
      hash = "sha256-wtH8yz1EHMNWPXN87N5qLn/zQaRiQzXQQvQbywLOpxE=";
    };
    aarch64-linux = {
      suffix = "arm64";
      hash = "sha256-Fj1KcQ9ZRjtALakIWQjxFAYxXK3QNYj7fJ2GwE+Nq/E=";
    };
  };

  arch =
    arches.${stdenv.hostPlatform.system}
    or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  # Everything the shipped binary dlopens or links against. This is the rpath
  # *and* the wrapper's LD_LIBRARY_PATH: Chromium loads several of these
  # (libva, vulkan, pipewire) by name at runtime, so rpath alone is not enough.
  deps = [
    stdenv.cc.cc
    nss
    nspr
    libGL
    libgbm
    libdrm
    libxkbcommon
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libXrender
    libxcb
    libxshmfence
    libXi
    libXcursor
    libXft
    libXScrnSaver
    libXtst
    libXt
    libSM
    libICE
    alsa-lib
    dbus
    cups
    ffmpeg
    libva
    pipewire
    wayland
    vulkan-loader
    systemd
    udev
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    freetype
    fontconfig
    libuuid
    expat
    zlib
    libxml2
    gtk3
    glib
    libkrb5
    snappy
  ];

  # $out is expanded by the shell at build time, in both the patchelf call and
  # the makeWrapper args — Helium's own bundled .so files live in opt/helium.
  libPath =
    lib.makeLibraryPath deps
    + lib.optionalString stdenv.hostPlatform.is64bit
    (":" + lib.makeSearchPathOutput "lib" "lib64" deps)
    + ":$out/opt/helium";
in
  stdenv.mkDerivation {
    pname = "helium";
    inherit version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_${arch.suffix}.deb";
      inherit (arch) hash;
    };

    # Prebuilt: nothing to configure or compile, and the ELF fixups below are
    # done by hand rather than by the generic hooks (which would also rewrite
    # Chromium's sandbox helper and strip its symbols).
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [
      binutils # `ar`, to crack open the .deb
      patchelf
      makeWrapper
      wrapGAppsHook3
    ];

    # Not in `deps`/rpath: these are here so wrapGAppsHook3 picks up their
    # schemas and icon themes for XDG_DATA_DIRS.
    buildInputs = [
      glib
      gsettings-desktop-schemas
      gtk3
      gtk4
      adwaita-icon-theme
    ];

    unpackPhase = ''
      runHook preUnpack
      ar x $src
      tar -xf data.tar.xz
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/opt
      cp -r opt/helium $out/opt/helium
      cp -r usr/share $out/share

      for bin in helium helium_crashpad_handler; do
        patchelf \
          --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
          --set-rpath "${libPath}" \
          $out/opt/helium/$bin
      done

      for lib in libEGL.so libGLESv2.so; do
        patchelf --set-rpath "${libPath}" $out/opt/helium/$lib
      done

      # Upstream's launcher resolves the binary relative to $HERE, which does
      # not survive being symlinked into $out/bin. It also hardcodes the distro
      # tag it reports in bug reports, which is not "deb" any more.
      substituteInPlace $out/opt/helium/helium-wrapper \
        --replace-fail '$HERE/helium' "$out/opt/helium/helium" \
        --replace-fail 'CHROME_VERSION_EXTRA=deb' 'CHROME_VERSION_EXTRA=nix'

      # A symlink, not a copy, so wrapGAppsHook3 wraps it in fixupPhase.
      ln -s $out/opt/helium/helium-wrapper $out/bin/helium

      # Every Exec= line — the main one and the desktop actions. `Icon=helium`
      # is left alone: the .deb ships its own hicolor icon, which the usr/share
      # copy above already put where the icon theme will find it.
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-fail 'Exec=helium' "Exec=$out/bin/helium"

      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${libPath}"
        --prefix PATH : ${lib.makeBinPath [xdg-utils coreutils]}
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
        ${lib.concatMapStringsSep "\n    " (f: ''--add-flags "${f}"'') flags}
      )
    '';

    meta = {
      description = "Private, fast, and honest web browser based on Chromium";
      homepage = "https://helium.computer";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "helium";
    };
  }
