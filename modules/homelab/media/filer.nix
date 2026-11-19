# SAFETY: Claude only advises; the Python app is the sole thing that touches the
# filesystem.
{
  den.aspects.homelab.media.filer.nixos = {
    config,
    pkgs,
    ...
  }: let
    inherit (pkgs) media-filer;

    queue = "${config.services.transmission.settings.download-dir}/.filer-queue";

    doneHook = pkgs.writeShellScript "transmission-done-filer" ''
      set -eu
      umask 0002
      tmp="${queue}/''${TR_TORRENT_HASH}.job.tmp"
      # Private-tracker announce URLs in TR_TORRENT_TRACKERS embed the passkey.
      ${pkgs.coreutils}/bin/env | ${pkgs.gnugrep}/bin/grep '^TR_' \
        | ${pkgs.gnused}/bin/sed -E 's/(passkey|authkey)=[^&[:space:],]*/\1=REDACTED/g' > "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "${queue}/''${TR_TORRENT_HASH}.job"
    '';
  in {
    users.users.media-filer = {
      isSystemUser = true;
      group = "media";
      description = "Files completed torrents into the Jellyfin library";
      home = "/var/lib/media-filer";
    };

    systemd.tmpfiles.rules = [
      "d ${queue} 2775 transmission media -"
    ];

    services.transmission.settings = {
      script-torrent-done-enabled = true;
      script-torrent-done-filename = "${doneHook}";
    };

    systemd.paths.media-filer = {
      wantedBy = ["multi-user.target"];
      pathConfig.DirectoryNotEmpty = queue;
    };

    systemd.services.media-filer = {
      description = "File completed torrents into the Jellyfin library";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.claude-code];
      serviceConfig = {
        Type = "oneshot";
        User = "media-filer";
        Group = "media";
        ExecStart = "${media-filer}/bin/media-filer ${queue}";

        StateDirectory = "media-filer";
        Environment = [
          "HOME=/var/lib/media-filer"
          "MEDIA_FILER_ROOT=${config.nice.media.root}"
        ];
        EnvironmentFile = config.age.secrets.media-filer-provider-keys.path;

        # BindPaths, not ReadWritePaths: the latter does not produce writable
        # mounts under our ZFS strict sandbox.
        ProtectSystem = "strict";
        BindPaths = [config.nice.media.root];
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
