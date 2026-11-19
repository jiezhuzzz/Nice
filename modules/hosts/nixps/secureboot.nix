# One-time firmware step, not expressible in Nix. On this Dell the relevant
# menu is Secure Boot -> Enable Custom Mode -> Custom Mode Key Management.
# Clearing the enrolled PK there puts the firmware in setup mode, which is
# the only state in which systemd-boot will auto-enroll our keys.
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
      autoGenerateKeys.enable = true;

      autoEnrollKeys = {
        enable = true;
        # Dropping Dell's OEM builtin-db and builtin-KEK can break vendor
        # firmware updates via fwupd.
        includeFirmwareBuiltinKeys = true;
        # includeMicrosoftKeys defaults to true and stays true — option ROMs on
        # this machine may be signed with them.
      };
    };

    # HACK: lanzaboote v1.1.0 orders `fwupd-efi` only before fwupd.service,
    # never after `generate-sb-keys`, so on first activation (or after key
    # regeneration) it fails on the not-yet-existent db.key. Remove if
    # lanzaboote gains this dependency upstream.
    systemd.services.fwupd-efi = lib.mkIf config.services.fwupd.enable {
      after = ["generate-sb-keys.service"];
      wants = ["generate-sb-keys.service"];
    };

    # The TPM2 keyslot is sealed to PCR 7 and enrolled imperatively
    # (systemd-cryptenroll writes to the LUKS header, not to Nix): keyslot 0
    # keeps the passphrase as the fallback, keyslot 1 holds the TPM2 token.
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

    environment.systemPackages = [pkgs.sbctl pkgs.efibootmgr];
  };
}
