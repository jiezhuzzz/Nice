{
  inputs,
  nice,
  ...
}: {
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.nixmachine.disko.nixos = {lib, ...}: let
    nvme0Id = "nvme-Samsung_SSD_9100_PRO_with_Heatsink_4TB_S7ZRNJ0Y700069V";
    nvme1Id = "nvme-Samsung_SSD_9100_PRO_with_Heatsink_4TB_S7ZRNJ0Y407276L";

    hddIds = {
      sdb = "ata-ST12000VN0008-2PH103_ZTN1C4RV";
      sdc = "ata-ST12000VN0008-2PH103_ZTN1CHSK";
      sdd = "ata-ST12000VN0008-2PH103_ZLW2JZGQ";
      sde = "ata-ST12000VN0008-2PH103_ZTN1DT63";
      sdf = "ata-ST12000VN0008-2PH103_ZL2P31JY";
      sdg = "ata-ST12000VN0008-3MH101_ZZ30HNRX";
      sdh = "ata-ST12000VN0008-2PH103_ZLW2JM3L";
      sdi = "ata-ST12000VN0008-3MH101_ZZ30E2PZ";
    };

    mkMountOptions = owner: group: mode: [
      "X-mount.owner=${owner}"
      "X-mount.group=${group}"
      "X-mount.mode=${mode}"
    ];
    mkSharedMountOptions = group: mkMountOptions "root" group "2775";
    mkUserMountOptions = mode: mkMountOptions nice.user.name "users" mode;

    mkHdd = id: {
      type = "disk";
      device = "/dev/disk/by-id/${id}";
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "tank";
          };
        };
      };
    };

    # Partition names matter: disko derives partlabels `disk-<diskname>-<partname>`
    # from them, and tank's special-vdev members reference those labels by literal
    # path below.
    mkNvme = id: espMount: {
      type = "disk";
      device = "/dev/disk/by-id/${id}";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = espMount;
              mountOptions = ["umask=0077"];
            };
          };
          special = {
            size = "512G";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
          rpool = {
            size = "1024G";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
          fast = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "fast";
            };
          };
        };
      };
    };
  in {
    imports = [inputs.disko.nixosModules.disko];

    disko.devices = {
      disk =
        {
          nvme0 = mkNvme nvme0Id "/boot";
          nvme1 = mkNvme nvme1Id "/boot/.fallback";
        }
        // lib.mapAttrs (_: mkHdd) hddIds;

      zpool = {
        rpool = {
          type = "zpool";
          mode = "mirror";
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
            dnodesize = "auto";
            mountpoint = "none";
            canmount = "off";
            "com.sun:auto-snapshot" = "false";
          };
          datasets = {
            "root" = {
              type = "zfs_fs";
              mountpoint = "/";
              options.mountpoint = "legacy";
            };
            "nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";
              options = {
                mountpoint = "legacy";
                atime = "off";
                recordsize = "128K";
              };
            };
            "home" = {
              type = "zfs_fs";
              mountpoint = "/home";
              options.mountpoint = "legacy";
            };
            "var" = {
              type = "zfs_fs";
              mountpoint = "/var";
              options.mountpoint = "legacy";
            };
            "var/log" = {
              type = "zfs_fs";
              mountpoint = "/var/log";
              options = {
                mountpoint = "legacy";
                recordsize = "16K";
                "com.sun:auto-snapshot" = "false";
              };
            };
            # Safety reserve so a 100%-full pool doesn't brick.
            "reserved" = {
              type = "zfs_fs";
              options = {
                mountpoint = "none";
                refreservation = "10G";
              };
            };
          };
        };

        # The special mirror is CRITICAL: lose both NVMes simultaneously and the
        # whole pool is gone.
        tank = {
          type = "zpool";
          mode.topology = {
            type = "topology";
            vdev = [
              {
                mode = "raidz2";
                members = ["sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi"];
              }
            ];
            special = [
              {
                mode = "mirror";
                members = [
                  "/dev/disk/by-partlabel/disk-nvme0-special"
                  "/dev/disk/by-partlabel/disk-nvme1-special"
                ];
              }
            ];
          };
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
            dnodesize = "auto";
            mountpoint = "none";
            canmount = "off";
          };
          # special_small_blocks must stay below recordsize, else ALL writes land
          # on the special vdev. Once special is full, overflow goes back to HDD
          # silently.
          datasets = {
            "media" = {
              type = "zfs_fs";
              mountpoint = "/tank/media";
              mountOptions = mkSharedMountOptions "media";
              options = {
                mountpoint = "legacy";
                recordsize = "1M";
                special_small_blocks = "0";
              };
            };
            "cache" = {
              type = "zfs_fs";
              options = {
                mountpoint = "none";
                canmount = "off";
                "com.sun:auto-snapshot" = "false";
              };
            };
            "cache/registry" = {
              type = "zfs_fs";
              mountpoint = "/tank/cache/registry";
              mountOptions = mkUserMountOptions "0700";
              options = {
                mountpoint = "legacy";
                recordsize = "1M";
                special_small_blocks = "0";
                compression = "lz4";
                atime = "off";
                "com.sun:auto-snapshot" = "false";
              };
            };
            "cache/models" = {
              type = "zfs_fs";
              mountpoint = "/tank/cache/models";
              mountOptions = mkUserMountOptions "0755";
              options = {
                mountpoint = "legacy";
                recordsize = "1M";
                special_small_blocks = "0";
                compression = "zstd-fast";
                atime = "off";
                "com.sun:auto-snapshot" = "false";
              };
            };
            # Not rebuildable despite sitting under `cache`. Mode 0711 so a
            # service user can traverse to its own subdirectory without listing
            # the rest.
            "cache/backups" = {
              type = "zfs_fs";
              mountpoint = "/tank/cache/backups";
              mountOptions = mkMountOptions "root" "root" "0711";
              options = {
                mountpoint = "legacy";
                special_small_blocks = "0";
                # Inert until a snapshot service exists; set so this doesn't
                # inherit the cache parent's `false`.
                "com.sun:auto-snapshot" = "true";
              };
            };
            "photos" = {
              type = "zfs_fs";
              mountpoint = "/tank/media/photos";
              mountOptions = mkSharedMountOptions "media";
              options = {
                mountpoint = "legacy";
                recordsize = "1M";
                special_small_blocks = "16K";
              };
            };
          };
        };

        # NO REDUNDANCY: losing either NVMe loses the entire pool. Keep canonical
        # copies of anything important on rpool, tank, or remote storage.
        fast = {
          type = "zpool";
          mode = ""; # empty mode = stripe
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            compression = "lz4";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
            dnodesize = "auto";
            mountpoint = "none";
            canmount = "off";
            "com.sun:auto-snapshot" = "false";
          };
          datasets = {
            "games" = {
              type = "zfs_fs";
              mountpoint = "/fast/games";
              mountOptions = mkSharedMountOptions "games";
              options = {
                mountpoint = "legacy";
                recordsize = "1M";
              };
            };
            "cache" = {
              type = "zfs_fs";
              mountpoint = "/fast/cache";
              mountOptions = mkUserMountOptions "0700";
              options = {
                mountpoint = "legacy";
                recordsize = "128K";
                refquota = "3T";
              };
            };
          };
        };
      };
    };
  };
}
