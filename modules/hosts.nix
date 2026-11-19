{nice, ...}: {
  den.hosts.x86_64-linux = {
    nixps = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApiDrorjoUu3XSvuzSEwDyMauOtmcqeRKW9SJWN1PT7";
      secrets = ["personal"];
      users.${nice.user.name} = {};
    };

    nixmachine = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhpaKcPL+8+O0D+Vb4wRdvVEGOv2zfeTSCgVRR9evZX";
      secrets = ["personal" "homelab"];
      users.${nice.user.name} = {};
    };
  };

  den.hosts.aarch64-darwin = {
    nixair = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILd3vgPew3ZkrxUrPxWieOlctLjqw9r0MH48HsAbNfcb";
      secrets = ["personal"];
      users.${nice.user.name} = {};
    };

    nixmini = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFdGfQiCHk30nWql1kwmIVPNzIkM9io+7Q9AqA4+y7k";
      secrets = ["personal"];
      users.${nice.user.name} = {};
    };

    nixneo = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJAekmUrW6WXWL2IWlhuvGQSq3MM2Zf94UJBzdZHEClJ";
      secrets = ["personal"];
      users.${nice.user.name} = {};
    };
  };

  den.homes.x86_64-linux = {
    chameleon.userName = "cc";

    goku = {
      userName = "jiezzz";
      homeDirectory = "/zp_goku/scratch_sb/jiezzz";
    };

    vegeta = {
      userName = "jiezzz";
      homeDirectory = "/zp_vegeta/scratch_sb/jiezzz";
    };
  };
}
