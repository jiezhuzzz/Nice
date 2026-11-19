# Steam Big Picture's Shutdown / Restart powers off the WHOLE box, killing the
# 24/7 homelab services. Use Big Picture's plain "Exit" instead.
{den, ...}: {
  den.aspects.gaming.includes = [den.aspects.gaming._];
}
