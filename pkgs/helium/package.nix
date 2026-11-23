# Refresh both hashes on a version bump: no host builds arm64 yet, so a stale
# one goes unnoticed until someone first builds on aarch64.
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
  flags ? [],
}: let
  version = "0.14.9.1";

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

  # Chromium dlopens several of these (libva, vulkan, pipewire) by name at
  # runtime, so rpath alone is not enough.
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

  # $out is left for the shell to expand at build time.
  libPath = "${lib.makeLibraryPath deps}:${lib.makeSearchPathOutput "lib" "lib64" deps}:$out/opt/helium";
in
  stdenv.mkDerivation {
    pname = "helium";
    inherit version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_${arch.suffix}.deb";
      inherit (arch) hash;
    };

    # The generic ELF hooks would also rewrite Chromium's sandbox helper and
    # strip its symbols.
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [
      binutils
      patchelf
      makeWrapper
      wrapGAppsHook3
    ];

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
      # not survive being symlinked into $out/bin.
      substituteInPlace $out/opt/helium/helium-wrapper \
        --replace-fail '$HERE/helium' "$out/opt/helium/helium" \
        --replace-fail 'CHROME_VERSION_EXTRA=deb' 'CHROME_VERSION_EXTRA=nix'

      # A symlink, not a copy, so wrapGAppsHook3 wraps it in fixupPhase.
      ln -s $out/opt/helium/helium-wrapper $out/bin/helium

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
      platforms = lib.attrNames arches;
      mainProgram = "helium";
    };
  }
