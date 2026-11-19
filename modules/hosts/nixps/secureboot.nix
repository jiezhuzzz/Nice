# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
#
# One-time firmware step, not expressible in Nix. On this Dell the relevant
# menu is Secure Boot -> Enable Custom Mode -> Custom Mode Key Management.
# Clearing the enrolled PK there puts the firmware in setup mode, which is
# the only state in which systemd-boot will auto-enroll our keys.
#
# As shipped the machine has builtin-PK/KEK/db plus microsoft (`sbctl status`),
# and clearing them destroys Dell's OEM certificates — hence
# includeFirmwareBuiltinKeys below, so enrollment puts them back.
#
# Recovery is disabling Secure Boot in the firmware, which is always
# available and does not depend on restoring the factory keys. Note the NixOS
# install medium is unsigned and will NOT boot while Secure Boot is active.
{inputs, ...}: {
  flake-file.inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote/v1.2.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.nixps.secureboot.nixos = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = [inputs.lanzaboote.nixosModules.lanzaboote];

    boot.lanzaboote = {
      enable = true;
      # sbctl 0.18's layout; lanzaboote reads keys/db/db.{pem,key} beneath it.
      pkiBundle = "/var/lib/sbctl";
      # `generate-sb-keys` runs `sbctl create-keys` once, guarded on the
      # absence of /var/lib/sbctl/keys.
      autoGenerateKeys.enable = true;

      # Writes PK/KEK/db .auth files to the ESP; systemd-boot performs the
      # actual firmware enrollment on the next boot, and only while the
      # firmware is in setup mode.
      autoEnrollKeys = {
        enable = true;
        # Re-enrol Dell's OEM certificates. Deleting the PK to reach setup mode
        # left builtin-db and builtin-KEK intact (`sbctl status`), and dropping
        # them can break vendor firmware updates via fwupd.
        includeFirmwareBuiltinKeys = true;
        # includeMicrosoftKeys defaults to true and stays true — option ROMs on
        # this machine may be signed with them.
        #
        # autoReboot stays off: the reboot that enrols is worth doing
        # deliberately, not as a side effect of `nixos-rebuild switch`.
      };
    };

    # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock. It used to
    # be pinned here against a default flip, but nixpkgs has since removed the
    # scripted initrd and turned `boot.initrd.systemd.enable` into a removed
    # option — defining it at all is now an eval error. systemd initrd is the
    # only initrd, so there is nothing left to guard.

    # Workaround for a lanzaboote v1.1.0 ordering bug. Lanzaboote defines both
    # `generate-sb-keys` (runs `sbctl create-keys`) and `fwupd-efi` (signs the
    # fwupd EFI app with the key that unit produces), but orders `fwupd-efi`
    # only `before = ["fwupd.service"]` — never after key generation. On a first
    # activation both start in the same transaction, `sbctl create-keys` takes a
    # few seconds, and `fwupd-efi` fails on the not-yet-existent db.key.
    # Harmless once keys exist; needed on first activation and after any key
    # regeneration. Remove if lanzaboote gains this dependency upstream.
    systemd.services.fwupd-efi = lib.mkIf config.services.fwupd.enable {
      after = ["generate-sb-keys.service"];
      wants = ["generate-sb-keys.service"];
    };

    # Unlock cryptroot from the TPM2 keyslot sealed to PCR 7, which measures
    # Secure Boot state and so survives kernel and generation updates without
    # re-enrolling. Enrolled imperatively (systemd-cryptenroll writes to the
    # LUKS header, not to Nix): keyslot 0 keeps the passphrase as the fallback,
    # keyslot 1 holds the TPM2 token.
    #
    # Anything that changes Secure Boot state — a firmware update, toggling
    # Secure Boot, re-enrolling keys — changes PCR 7 and breaks the seal. The
    # symptom is the passphrase prompt returning, with this in the journal:
    #
    #   systemd-cryptsetup: TPM policy does not match current system state.
    #
    # To re-seal, boot once into the new steady state (PCR 7 is measured early
    # in boot and frozen, so sealing in the same boot as the change binds a
    # stale value), then:
    #
    #   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
    #     --wipe-slot=tpm2 /dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9
    #
    # --wipe-slot is required: systemd-cryptenroll no-ops on an already
    # enrolled PCR set rather than replacing it.
    boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["tpm2-device=auto"];

    # sbctl inspects/verifies Secure Boot state. efibootmgr edits the firmware
    # boot entries that bootctl can only report on — the repair tool if
    # enrollment leaves the machine booting the wrong entry.
    environment.systemPackages = [pkgs.sbctl pkgs.efibootmgr];
  };
}
