# Firewall holes live with each service module.
{den, ...}: {
  den.aspects.homelab.media.includes = [den.aspects.homelab.media._];
}
