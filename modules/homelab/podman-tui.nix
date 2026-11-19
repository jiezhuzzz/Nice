# podman-tui reads no CONTAINER_HOST or containers.conf, only this file, and
# otherwise defaults to the rootless socket. Declaring it breaks the UI's
# connection editor, which rewrites the file.
{
  den.aspects.homelab.podman-tui.homeManager = {pkgs, ...}: let
    jsonFormat = pkgs.formats.json {};
  in {
    xdg.configFile."podman-tui/podman-tui.json".source = jsonFormat.generate "podman-tui.json" {
      connections.localhost = {
        uri = "unix:///run/podman/podman.sock";
        default = true;
      };
    };
  };
}
