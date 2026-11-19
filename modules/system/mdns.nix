# mDNS / zeroconf via Avahi. Advertises this host's `networking.hostName` on the
# LAN as `<hostname>.local`, so services can link to each other by name instead of
# a DHCP-assigned IP, and lets this box resolve other `.local` names too. Avahi
# manages its own firewall opening for the mDNS port (UDP 5353).
{
  den.aspects.mdns.nixos = {
    services.avahi = {
      enable = true;
      nssmdns4 = true; # resolve other hosts' <name>.local from this machine
      settings.publish = {
        disable-publishing = false;
        publish-addresses = true; # advertise this host's A records as <hostname>.local
      };
      openFirewall = true; # UDP 5353
    };
  };
}
