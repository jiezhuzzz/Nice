# Forgejo — self-hosted git forge, plus the Actions runner that executes its
# CI. Two units with very different exposure (the forge is loopback-only; the
# runner has to punch a hole in the podman bridge for job containers), so they
# get a file each.
{den, ...}: {
  den.aspects.homelab.forgejo.includes = [den.aspects.homelab.forgejo._];
}
