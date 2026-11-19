# Not packaged in nixpkgs, hence the OCI container.
{
  den.aspects.homelab.media.metatube.nixos = {
    virtualisation.oci-containers = {
      backend = "podman";
      containers.metatube = {
        image = "ghcr.io/metatube-community/metatube-server@sha256:04d58879b76624e180cfdb24cde042b657189eabd3bd4cba851f1d56f7a5be82";
        ports = ["127.0.0.1:8080:8080"];
        volumes = ["/var/lib/metatube:/config"];
        cmd = [
          "-bind"
          "0.0.0.0" # inside the netns; the host only publishes to 127.0.0.1
          "-port"
          "8080"
          "-dsn"
          "/config/metatube.db"
          "-db-auto-migrate"
        ];
      };
    };

    # The bind-mount source must exist before Podman resolves it.
    systemd.services.podman-metatube.serviceConfig = {
      StateDirectory = "metatube";
      StateDirectoryMode = "0750";
    };
  };
}
