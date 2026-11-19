{
  den.aspects.nixmachine.loudness.nixos = {pkgs, ...}: {
    services.pipewire = {
      # NixOS pins PipeWire's LADSPA_PATH to a curated buildEnv, so plugins must be
      # added here (a raw file path is NOT searched).
      extraLadspaPackages = [pkgs.caps];

      extraConfig.pipewire."99-loudness" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            flags = ["nofail"];
            args = {
              "node.description" = "Loudness";
              "media.name" = "Loudness";
              "filter.graph" = {
                nodes = [
                  {
                    type = "ladspa";
                    name = "compressor";
                    plugin = "caps";
                    label = "CompressX2";
                    control = {
                      "threshold" = 0.4;
                      "strength" = 0.35;
                      "attack" = 0.75;
                      "release" = 0.5;
                      "gain (dB)" = 6.0;
                    };
                  }
                ];
                inputs = ["compressor:in.l" "compressor:in.r"];
                outputs = ["compressor:out.l" "compressor:out.r"];
              };
              "capture.props" = {
                "node.name" = "loudness_sink";
                "node.description" = "Loudness (console-style)";
                "media.class" = "Audio/Sink";
                "audio.channels" = 2;
                "audio.position" = ["FL" "FR"];
              };
              "playback.props" = {
                "node.name" = "loudness_output";
                "node.passive" = true;
                "audio.channels" = 2;
                "audio.position" = ["FL" "FR"];
                "target.object" = "alsa_output.pci-0000_c3_00.1.hdmi-stereo-extra1";
              };
            };
          }
        ];
      };
    };
  };
}
